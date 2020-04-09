#pyinstaller -F -i "./images/icon.ico" Download-Latest-Cumulative-Update.py

from tkinter import *
from tkinter.ttk import * # for combobox component
from tkinter import filedialog # for taget location component (file explorar)
import subprocess, sys #let he program use cmd command executions
import time
from tkinter import messagebox
import asyncio

#global variables:
fontSize = 12
global_pady = 10

#Form definitions:
window = Tk()
window.title("DOWNLOAD LATEST CUMULATIVE UPDATE")
window.geometry('500x400')

## ## row 0: - Top Frame:
topFrame_lbl = Label(window, text="", font=("Arial Bold", fontSize), justify = "left")
topFrame_lbl.grid(column=0, row=0)


## row 1:
windows_lbl = Label(window, text="Windows 10: ", font=("Arial Bold", fontSize))
windows_lbl.grid(column=1, row=1,pady=global_pady)

architecture_combobox = Combobox(window, justify ="center", width=7,font=("Arial Bold", fontSize))
architecture_combobox['values']= ("x64", "x86")
architecture_combobox.current(1) #set the selected item
architecture_combobox.grid(column=2, row=1,pady=global_pady)

build_lbl = Label(window, text=" Build: ", font=("Arial Bold", fontSize))
build_lbl.grid(column=5, row=1,pady=global_pady)

version_combobox = Combobox(window, justify ="center", width=7,font=("Arial Bold", fontSize))
version_combobox['values']= ("1909", "1903", "1809")
version_combobox.current(1) #set the selected item
version_combobox.grid(column=6, row=1,pady=global_pady)

## row 2:
target_lbl = Label(window, text="Target Location: ", font=("Arial Bold", fontSize))
target_lbl.grid(column=1, row=2,pady=global_pady, padx= (25,0))

def browse_button():
    # Allow user to select a directory and store it in global var
    # called folder_path
    folder_selected = filedialog.askdirectory()
    print (folder_selected)
    folder_selected_fixed = str(folder_selected).replace("/", "\\")
    folderPath_txtBox.delete(0,"end") #Claer content
    folderPath_txtBox.insert(0,folder_selected_fixed) # Set new content

folderPath_txtBox = Entry(window,width=40)
folderPath_txtBox.grid(column=2, row=2,columnspan = 4,pady=global_pady)
folderPath_txtBox.insert(0,"C:\\")

folderExplorer_btn = Button(text="...", command=browse_button)
folderExplorer_btn.grid(column=6, row = 2,pady=global_pady)


## row 3:
def request(command):
    loop = asyncio.get_event_loop()
    process = subprocess.Popen(["powershell.exe",command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()
    out_str = out.decode("utf-8")
    print(out_str)
    output_txtBox.delete(1.0,END) #Claer content
    output_txtBox.insert(INSERT,out_str) # Set new content

def show_btn_action():
    output_txtBox.delete(1.0,END) #Claer content
    output_txtBox.insert(INSERT,"WORKING") # Set new content
    command= ".\Invoke-MSLatestUpdateDownload.ps1 -UpdateType CumulativeUpdate -OSBuild \""
    command += version_combobox.get() + "\" -OSArchitecture \""
    command += architecture_combobox.get() + "-based\""
    command += " -List \n"
    print (command + "\n\n WORKING, PLEASE WAIT.... \n\n")
    request(command)
    messagebox.showinfo('Finished','The process has finished.')
    output_txtBox.delete(1.0,END) #Claer content
    output_txtBox.insert(INSERT,"") # Set new content
        

def download_btn_action():
    if(folderPath_txtBox.get() != "" or folderPath_txtBox.get() == "C:\\"):
        command= ".\Invoke-MSLatestUpdateDownload.ps1 -UpdateType CumulativeUpdate -Path \""
        command += folderPath_txtBox.get() + "\" -OSBuild \""
        command += version_combobox.get() + "\" -OSArchitecture \""
        command += architecture_combobox.get() + "-based\""
        print (command + "\n\n WORKING, PLEASE WAIT.... \n\n")
        request(command)
        messagebox.showinfo('Finished','The process has finished.')
        output_txtBox.delete(1.0,END) #Claer content
        output_txtBox.insert(INSERT,"") # Set new content
    else:
        messagebox.showinfo(title="ERROR", message="Download folder destination has not been set")

show_btn = Button(text="Show", command=show_btn_action)
show_btn.grid(column=1, row = 3, columnspan = 2, sticky = W+E,pady=global_pady, padx = (20,0))

download_btn = Button(text="Download", command=download_btn_action)
download_btn.grid(column=4, row = 3, columnspan = 5, sticky = W+E,pady=global_pady)

## row 4:
from tkinter.scrolledtext import ScrolledText
output_txtBox = ScrolledText(window,width=40, height=13 )
output_txtBox.grid(column=1, row=4,columnspan = 6, sticky = W+E,pady=global_pady, padx = (20,0))

window.mainloop()