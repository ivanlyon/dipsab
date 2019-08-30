'''
dipsab is an acronym for Directory Images Padded, Stacked And Bordered.
'''

import copy
import json
import os
import sys
import tkinter
import tkinter.ttk as ttk
from tkinter import filedialog, simpledialog, messagebox, colorchooser
from PIL import Image, ImageTk
import dirim

__version__ = "0.1.0"
__license__ = "MIT"

DISPLAY_NAME = "dipsab"
DEFAULT_SECTION = {'directory':'', 'hpad':10, 'vpad':10}
DEFAULT_PROPS = {}
DEFAULT_PROPS['bgcolor'] = '#000000'
DEFAULT_PROPS['bordersize'] = 40
DEFAULT_PROPS['hsize'] = 1920
DEFAULT_PROPS['vsize'] = 1080
DEFAULT_PROPS['header'] = 0
DEFAULT_PROPS['footer'] = 0
DEFAULT_PROPS['exportpath'] = ''

def aspect_rationate(available, candidate):
    "Compute height and width retainining aspect ratio constrained by available space."

    if candidate[0] > available[0] or candidate[1] > available[1]:
        factor = min(available[0] / candidate[0], available[1] / candidate[1])
        result = (int(factor * candidate[0]), int(factor * candidate[1]))
    else:
        result = candidate

    return result

def ok_dialog(parent, dialog_title, dialog_text):
    "Display configured text + title and exit upon 'OK' button click."
    top = tkinter.Toplevel(parent)
    top.title(dialog_title)

    textlabel = tkinter.Label(top, text=dialog_text, justify=tkinter.LEFT)
    textlabel.pack(fill=tkinter.BOTH)

    ok_button = tkinter.Button(top, text='OK', command=top.destroy)
    ok_button.pack(fill=tkinter.X)

###############################################################################

class PropertiesDialog(simpledialog.Dialog):
    "Modal dialog of each layer's content and appearance attributes."

    def __init__(self, master, config, *args, **kwargs):
        self.bgcolor = config['bgcolor']
        self.bgcolor_var = tkinter.StringVar()
        self.bgcolor_var.set(self.bgcolor)

        self.bordersize = config['bordersize']
        self.bordersize_var = tkinter.IntVar()
        self.bordersize_var.set(self.bordersize)

        self.hsize = config['hsize']
        self.hsize_var = tkinter.IntVar()
        self.hsize_var.set(self.hsize)

        self.vsize = config['vsize']
        self.vsize_var = tkinter.IntVar()
        self.vsize_var.set(self.vsize)

        self.header = config['header']
        self.header_var = tkinter.IntVar()
        self.header_var.set(self.header)

        self.footer = config['footer']
        self.footer_var = tkinter.IntVar()
        self.footer_var.set(self.footer)

        simpledialog.Dialog.__init__(self, master,
                                     title=DISPLAY_NAME + " Properties",
                                     *args, **kwargs)

    def body(self, master):
        tkinter.Label(master, text="Border Color").grid(row=0)
        self.en0 = tkinter.Entry(master, textvariable=self.bgcolor_var)
        self.en0.grid(row=0, column=1, sticky='ew')
        self.bn0 = tkinter.Button(master, text="...", command=lambda: self.choose_color())
        self.bn0.grid(row=0, column=2)

        tkinter.Label(master, text="Border Size").grid(row=1)
        self.sb0 = tkinter.Spinbox(master, from_=0, to=200, textvariable=self.bordersize_var)
        self.sb0.grid(row=1, column=1)

        tkinter.Label(master, text="Horizontal Size").grid(row=2)
        self.sb1 = tkinter.Spinbox(master, from_=0, to=4096, textvariable=self.hsize_var)
        self.sb1.grid(row=2, column=1)

        tkinter.Label(master, text="Vertical Size").grid(row=3)
        self.sb2 = tkinter.Spinbox(master, from_=0, to=4096, textvariable=self.vsize_var)
        self.sb2.grid(row=3, column=1)

        tkinter.Label(master, text="Header").grid(row=4)
        self.cb1 = tkinter.Checkbutton(master, text='First Layer', variable=self.header_var)
        self.cb1.grid(row=4, column=1, sticky='w')

        tkinter.Label(master, text="Footer").grid(row=5)
        self.cb2 = tkinter.Checkbutton(master, text='Last Layer', variable=self.footer_var)
        self.cb2.grid(row=5, column=1, sticky='w')

        return None

    def choose_color(self):
        "Browse for directory to be depicted as a layer in the shadowbox"

        (triple, hexstr) = colorchooser.askcolor(self.bgcolor)
        if hexstr:
            self.bgcolor_var.set(hexstr)

    def apply(self):
        self.bgcolor = self.bgcolor_var.get()
        self.bordersize = self.bordersize_var.get()
        self.hsize = self.hsize_var.get()
        self.vsize = self.vsize_var.get()
        self.header = self.header_var.get()
        self.footer = self.footer_var.get()

###############################################################################

class LayerDialog(simpledialog.Dialog):
    "Modal dialog of each layer's content and appearance attributes."

    def __init__(self, master, layer, number, *args, **kwargs):
        self.layer_dir = layer['directory']
        self.layer_dir_var = tkinter.StringVar()
        self.layer_dir_var.set(self.layer_dir)

        self.hpad = layer['hpad']
        self.hpad_var = tkinter.IntVar()
        self.hpad_var.set(self.hpad)

        self.vpad = layer['vpad']
        self.vpad_var = tkinter.IntVar()
        self.vpad_var.set(self.vpad)

        dialog_title = DISPLAY_NAME + " Layer " + str(number) + " Configuration"
        simpledialog.Dialog.__init__(self, master, title=dialog_title, *args, **kwargs)

    def body(self, master):
        "Configure Layer Dialog widgets"

        tkinter.Label(master, text="Layer Directory").grid(row=0)
        self.en0 = tkinter.Entry(master, textvariable=self.layer_dir_var)
        self.en0.grid(row=0, column=1, sticky='ew')
        self.bn0 = tkinter.Button(master, text="...",
                                  command=lambda: self.choose_dir(master))
        self.bn0.grid(row=0, column=2)

        tkinter.Label(master, text="Padding, Vertical").grid(row=1)
        self.sb0 = tkinter.Spinbox(master, from_=0, to=400, textvariable=self.vpad_var)
        self.sb0.grid(row=1, column=1)

        tkinter.Label(master, text="Padding, Horizontal").grid(row=2)
        self.sb1 = tkinter.Spinbox(master, from_=0, to=400, textvariable=self.hpad_var)
        self.sb1.grid(row=2, column=1)

        return None

    def choose_dir(self, master):
        "Browse for directory to be depicted as a layer in the shadowbox"

        result = filedialog.askdirectory(parent=master)
        if result:
            self.layer_dir_var.set(result)

    def apply(self):
        self.layer_dir = self.layer_dir_var.get()
        self.hpad = self.hpad_var.get()
        self.vpad = self.vpad_var.get()

###############################################################################

class LayerPanel(ttk.Frame):
    "Addition and modification of shadowbox content."

    def __init__(self, parent):
        ttk.Frame.__init__(self, parent, style='My.TFrame')
        self.parent = parent
        self.buttons = []
        self.config(border=1, relief=tkinter.GROOVE)
        self.pack()

    def config_layer(self, number):
        "Sample function provided to show how a toolbar command may be used."

        layerconfig = LayerDialog(self, self.parent.sections[number], number + 1)
        result = {'directory':layerconfig.layer_dir,
                  'hpad':layerconfig.hpad,
                  'vpad':layerconfig.vpad}
        self.parent.assign_section(number, result)

    def load(self, len_sections):
        "Load layers into layer panel."

        self.clear()
        for index in range(len_sections):
            _button_text = str(index + 1)
            self.buttons.append(ttk.Button(self, text=_button_text,
                                           command=lambda i=index: self.config_layer(i)))
            self.buttons[index].pack(side=tkinter.TOP, fill=tkinter.X)
            self.pack()

    def clear(self):
        "Remove layers from layer panel."

        while self.buttons:
            self.buttons[-1].destroy()
            del self.buttons[-1]

###############################################################################

class StatusBar(ttk.Frame):
    "Bottom of GUI displays state information one-liners."

    def __init__(self, parent):
        ttk.Frame.__init__(self, parent)
        self.labels = []
        self.config(border=1, relief=tkinter.GROOVE)
        self.label = ttk.Label(self, text='Unset')
        self.label.pack(side=tkinter.LEFT, fill=tkinter.X)
        self.pack()

    def set_text(self, new_text):
        "Assign status bar text"

        self.label.config(text=new_text)

    def display_props(self, props):
        "Display attributes from the properties dictionary."

        result = 'Export configuration: '
        result += str(props['hsize']) + ' x '
        result += str(props['vsize']) + ' - '
        if props['exportpath']:
            result += props['exportpath']
        else:
            result += '(No export path exists)'
        self.set_text(result)

###############################################################################

class MainFrame(ttk.Frame):
    "Main area of user interface content."

    def __init__(self, parent):
        ttk.Frame.__init__(self, parent)
        self.display_area = tkinter.Label(parent)
        self.display_area.image = None
        self.display_area.pack(fill=tkinter.BOTH, expand=1)
        self.bind("<Configure>", self._resize_binding)
        self.unsized_image = None

    def render_resized(self):
        "Create preview image resized to viewing area."

        if self.unsized_image:
            widget_sizes = (self.display_area.winfo_width(), self.display_area.winfo_height())
            ratiocinated = aspect_rationate(widget_sizes, self.unsized_image.size)
            picture2 = self.unsized_image.resize(ratiocinated)
            tkimage = ImageTk.PhotoImage(picture2)
            self.display_area.config(image=tkimage)
            self.display_area.image = tkimage
        else:
            self.display_area.config(image=None)
            self.display_area.image = None

    def show_image(self, picture):
        "Begin process of creating the preview image and configure for resizing."

        self.display_area.update()
        self.unsized_image = picture
        self.render_resized()
        self.display_area.pack(fill=tkinter.BOTH, expand=1)

    def _resize_binding(self, event):
        if self.unsized_image:
            self.render_resized()

###############################################################################

class ToolBar(ttk.Frame):
    "Sample toolbar provided by cookiecutter switch."

    def __init__(self, parent):
        ttk.Frame.__init__(self, parent, style='My.TFrame')
        self.parent = parent
        self.buttons = []
        self.config(border=1, relief=tkinter.GROOVE)
        self.add_button = ttk.Button(self, text=u"\u271A", command=self.add_layer)
        self.add_button.pack(side=tkinter.LEFT, fill=tkinter.X)
        self.del_button = ttk.Button(self, text=u"\u2796", command=self.del_layer)
        self.del_button.pack(side=tkinter.LEFT, fill=tkinter.X)
        self.up_button = ttk.Button(self, text=u"\u2963", command=self.raise_layer)
        self.up_button.pack(side=tkinter.LEFT, fill=tkinter.X)
        self.dn_button = ttk.Button(self, text=u"\u2965", command=self.lower_layer)
        self.dn_button.pack(side=tkinter.LEFT, fill=tkinter.X)
        self.pack()
        self.enabling()

    def add_layer(self):
        "Add a default valued layer to the layer panel."

        self.parent.add_section()
        self.enabling()

    def del_layer(self):
        "Remove a layer from the sequence of layers. No Undo provided."

        number = self.parent.len_sections()
        prompt = 'Layer to be deleted (1 - ' + str(number) + ')'
        deleting = simpledialog.askinteger('Delete Layer', prompt)
        if deleting:
            deleting -= 1
            if 0 <= deleting < number:
                self.parent.del_section(deleting)
                self.enabling()
            else:
                messagebox.showerror('Invalid', 'Invalid layer number entered')
                self.del_layer()

    def raise_layer(self):
        "Swap a designated layer with its nearest upwards neighbor."

        number = self.parent.len_sections()
        prompt = 'Layer to be raised (2 - ' + str(number) + ')'
        raising = simpledialog.askinteger('Raise Layer', prompt)
        if raising:
            raising -= 1
            if 1 <= raising < number:
                self.parent.swap_sections(raising, raising - 1)
            else:
                messagebox.showerror('Invalid', 'Invalid layer number entered')
                self.raise_layer()

    def lower_layer(self):
        "Swap a designated layer with its nearest downwards neighbor."

        number = self.parent.len_sections()
        prompt = 'Layer to be lowered (1 - ' + str(number - 1) + ')'
        lowering = simpledialog.askinteger('Lower Layer', prompt)
        if lowering:
            lowering -= 1
            if 0 <= lowering < number - 1:
                self.parent.swap_sections(lowering, lowering + 1)
            else:
                messagebox.showerror('Invalid', 'Invalid layer number entered')
                self.lower_layer()

    def enabling(self):
        "Enable toolbar buttons according to existence of layers available."

        if self.parent.sections:
            self.del_button.config(state='active')
            self.up_button.config(state='active')
            self.dn_button.config(state='active')
        else:
            self.del_button.config(state='disabled')
            self.up_button.config(state='disabled')
            self.dn_button.config(state='disabled')

###############################################################################

class Dipsab(tkinter.Tk):
    "Top level class over all the functionality of this program."

    def __init__(self):
        tkinter.Tk.__init__(self)
        self.wm_geometry('800x600')
        self.props = copy.deepcopy(DEFAULT_PROPS)

        self.style = ttk.Style()
#        self.style.configure('TFrame', background='#666666')
        self.style.configure('My.TFrame', background='#777777')
#        self.style.configure('My.TButton', background='#111111')

        #TODO: Add and implement dirty bit + visualization
        self.sections = []
        self.exportpath = ''
        self.filename = ''
        self.set_filename('')

        self.statusbar = StatusBar(self)
        self.statusbar.pack(side='bottom', fill='x')
        self.statusbar.set_text('No errors')

        self.toolbar = ToolBar(self)
        self.toolbar.pack(side='top', fill='x')

        self.layerpanel = LayerPanel(self)
        self.layerpanel.pack(side='left', fill='y')

        self.mainframe = MainFrame(self)
        self.mainframe.pack(side='right', fill='y')

        self.menubar = tkinter.Menu(self)
        self.filemenu = tkinter.Menu(self.menubar, tearoff=False)
        self.filemenu.add_command(label='New', command=self.new_dialog)
        self.filemenu.add_command(label='Open', command=self.open_dialog)
        self.filemenu.add_command(label='Save', command=self.save)
        self.filemenu.add_command(label='Save As', command=self.save_as_dialog)
        self.filemenu.add_separator()
        self.filemenu.add_command(label='Properties', command=self.image_setup_dialog)
        self.filemenu.add_command(label='Export', command=self.export)
        self.filemenu.add_command(label='Export As', command=self.export_as_dialog)
        self.filemenu.add_separator()
        self.filemenu.add_command(label='Exit', underline=1, command=self.quit)

        self.viewmenu = tkinter.Menu(self.menubar, tearoff=False)
        self.viewmenu.add_command(label='Render', command=self.render_image)

        self.helpmenu = tkinter.Menu(self.menubar, tearoff=False)
        self.helpmenu.add_command(label='About', command=self.about_dialog)

        self.menubar.add_cascade(label='File', underline=0, menu=self.filemenu)
        self.menubar.add_cascade(label='View', underline=0, menu=self.viewmenu)
        self.menubar.add_cascade(label='Help', underline=0, menu=self.helpmenu)
        self.config(menu=self.menubar)

        self.render_exportable()
        self.statusbar.display_props(self.props)

    def render_exportable(self):
        "Toggle state of export path according to existence of variable content."

        if self.exportpath:
            self.filemenu.entryconfigure("Export", state="normal")
        else:
            self.filemenu.entryconfigure("Export", state="disabled")

    def quit(self):
        "Ends toplevel execution."

        sys.exit(0)

    def about_dialog(self):
        "Dialog concerning information about entities responsible for program."

        _description = 'wat: Directory Images Padded, Stacked And Bordered'
        _description += '\nVersion: ' + __version__
        _description += '\nLicense: ' + __license__
        _description += '\nGitHub: ivanlyon/' + DISPLAY_NAME
        ok_dialog(self, 'About ' + DISPLAY_NAME, _description)

    def new_dialog(self):
        "Clear application to startup default values."

        self.set_filename('')
        self.props = copy.deepcopy(DEFAULT_PROPS)
        self.layerpanel.clear()
        self.sections = []
        self.render_image()

    def open_dialog(self):
        "Standard askopenfilename() invocation and result handling."

        _name = filedialog.askopenfilename()
        if isinstance(_name, str):
            self.layerpanel.clear()
            with open(_name) as json_file:
                configuration = json.load(json_file)
                self.props = configuration[0]
                self.sections = configuration[1]
                self.set_filename(_name)
                self.exportpath = self.props['exportpath']
            self.layerpanel.load(len(self.sections))
            self.toolbar.enabling()
            self.render_image()
        else:
            print('No file selected')

    def save_as_dialog(self):
        "Standard asksaveasfilename() invocation and result handling."

        _name = filedialog.asksaveasfilename()
        if _name:
            self.set_filename(_name)
            self.save()

    def save(self):
        "Save configuration in json file format to a pre-determined filename."

        if self.filename:
            configuration = []
            configuration.append(self.props)
            configuration.append(self.sections)
            with open(self.filename, "w") as file:
                json.dump(configuration, file, indent=4)
        else:
            self.save_as_dialog()

    def export_as_dialog(self):
        "Standard asksaveasfilename() invocation and result handling."

        _name = filedialog.asksaveasfilename()
        if _name:
            if not _name.endswith('.jpg'):
                self.exportpath = _name + '.jpg'
            else:
                self.exportpath = _name
            self.props['exportpath'] = self.exportpath
            self.export()

    def export(self):
        "Standard askopenfilename() invocation and result handling."

        if self.exportpath:
            self.create_image().save(self.exportpath)
        else:
            messagebox.showerror('Export Error', 'No export file name configured')
        self.statusbar.display_props(self.props)

    def image_setup_dialog(self):
        "Standard dialog input and handling."

        new_props = PropertiesDialog(self, self.props)
        if new_props:
            self.props['bgcolor'] = new_props.bgcolor
            self.props['bordersize'] = new_props.bordersize
            self.props['hsize'] = new_props.hsize
            self.props['vsize'] = new_props.vsize
            self.props['header'] = new_props.header
            self.props['footer'] = new_props.footer
            self.render_image()

    def set_filename(self, newname):
        "Set the class variable 'filename' and update application title"

        self.filename = newname
        head, tail = os.path.split(newname)
        results = [tail, head, DISPLAY_NAME]
        new_title = [r for r in results if r]
        self.wm_title(' - '.join(new_title))

    def create_image(self):
        "Draw the image in the drawing area."

        offset_x = self.props['bordersize']
        top_y = self.props['bordersize']
        bottom_y = self.props['vsize'] - self.props['bordersize']
        layer_imgs = []
        args = {}
        args['bgcolor'] = self.props['bgcolor']
        args['width'] = self.props['hsize'] - 2 * self.props['bordersize']
        for layer in self.sections:
            args['hpad'] = layer['hpad']
            args['vpad'] = layer['vpad']
            args['input'] = layer['directory']
            layer_imgs.append(dirim.dirim(args))

        image = Image.new('RGB', (self.props['hsize'], self.props['vsize']),
                          color=self.props['bgcolor'])

        if self.props['header']:
            image.paste(layer_imgs[0], (offset_x, top_y))
            top_y += layer_imgs[0].size[1]
            del layer_imgs[0]

        if self.props['footer'] and layer_imgs:
            bottom_y -= layer_imgs[-1].size[1]
            image.paste(layer_imgs[-1], (offset_x, bottom_y))
            del layer_imgs[-1]

        total_height = sum(i.size[1] for i in layer_imgs)
        total_height += self.props['bordersize'] * (len(layer_imgs) - 1)

        offset_y = top_y + (bottom_y - top_y - total_height) // 2
        #TODO: handle offset_y < border

        for layer in layer_imgs:
            image.paste(layer, (offset_x, offset_y))
            offset_y += layer.size[1] + self.props['bordersize']

        return image

    def render_image(self):
        "Draw the image in the drawing area."

        for idx, layer in enumerate(self.sections, start=1):
            if not os.path.isdir(layer['directory']):
                self.statusbar.set_text('ERROR: invalid location in layer ' + str(idx))
                return

        self.render_exportable()
        self.statusbar.display_props(self.props)
        self.mainframe.show_image(self.create_image())

    def len_sections(self):
        "Return the number of sections. Included to limit direct access of class variable."

        return len(self.sections)

    def del_section(self, number):
        "Delete a section from the current sequence."

        del self.sections[number]
        self.render_image()
        self.layerpanel.load(len(self.sections))

    def add_section(self):
        "Append a section to the current sequence."

        number = len(self.sections)
        self.sections.append(DEFAULT_SECTION)
        self.layerpanel.load(number + 1)
        self.layerpanel.config_layer(number)

    def swap_sections(self, one, other):
        "Swap 2 layers of the image and render the result."

        self.sections[one], self.sections[other] = self.sections[other], self.sections[one]
        self.render_image()

    def assign_section(self, number, configuration):
        "Assign section layer configuration values."

        for k in configuration:
            self.sections[number][k] = configuration[k]
        self.render_image()

###############################################################################

if __name__ == '__main__':
    APPLICATION_GUI = Dipsab()
    APPLICATION_GUI.mainloop()
