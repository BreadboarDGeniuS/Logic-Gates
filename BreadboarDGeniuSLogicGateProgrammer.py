# BreadboarD GeniuS Logic + Counter Programmer
# Cross-platform Python GUI (Windows, Linux, macOS)

import os
import sys
import platform
import subprocess
import xml.etree.ElementTree as ET
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from datetime import datetime
from serial.tools import list_ports

# --- Globals ---
CONFIG_FILE = "BreadboarDGeniuSLogicProgrammer.xml"
LOG_DIR = os.getcwd()
HEX_LOGIC = []     # List of {name, path}
HEX_COUNTER = []   # List of {name, path}
PROG_PY_PATH = ""
COM_PORT = None
LOG_FILENAME = ""

# --- Utility Functions ---
def get_next_log_filename():
    index = 1
    while True:
        filename = os.path.join(LOG_DIR, f"packdata{index}.txt")
        if not os.path.exists(filename):
            return filename
        index += 1

def load_config():
    global PROG_PY_PATH, HEX_LOGIC, HEX_COUNTER
    if not os.path.exists(CONFIG_FILE):
        return
    tree = ET.parse(CONFIG_FILE)
    root = tree.getroot()
    
    PROG_PY_PATH = root.findtext("progPyPath", default="")

    HEX_LOGIC.clear()
    for file in root.findall("LogicHexFiles/File"):
        HEX_LOGIC.append({"name": file.attrib["Name"], "path": file.text})

    HEX_COUNTER.clear()
    for file in root.findall("CounterHexFiles/File"):
        HEX_COUNTER.append({"name": file.attrib["Name"], "path": file.text})

def save_config():
    root = ET.Element("Configuration")
    ET.SubElement(root, "progPyPath").text = PROG_PY_PATH

    logic_elem = ET.SubElement(root, "LogicHexFiles")
    for entry in HEX_LOGIC:
        e = ET.SubElement(logic_elem, "File", Name=entry["name"])
        e.text = entry["path"]

    counter_elem = ET.SubElement(root, "CounterHexFiles")
    for entry in HEX_COUNTER:
        e = ET.SubElement(counter_elem, "File", Name=entry["name"])
        e.text = entry["path"]

    ET.ElementTree(root).write(CONFIG_FILE)

def detect_ch340_port():
    for port in list_ports.comports():
        if "CH340" in port.description or "CH34" in port.description:
            return port.device
    return None

def log_device_output(option_name, output):
    global LOG_FILENAME
    if not LOG_FILENAME:
        LOG_FILENAME = get_next_log_filename()

    lines = output.splitlines()
    serial = rev = famid = devid = "Not found"
    for line in lines:
        if "Device serial number:" in line:
            serial = line.split(":")[-1].strip()
        elif "Device ID:" in line:
            devid = line.split("'")[1]
        elif "Device revision:" in line:
            rev = line.split("'")[1]
        elif "Device family ID:" in line:
            famid = line.split("'")[1]

    with open(LOG_FILENAME, "a") as f:
        f.write(f"Device family ID: {famid}, Device ID: {devid}, Device serial number: {serial}, Device revision: {rev}, {option_name}\n")

# --- Command Execution ---
def run_prog_py(hex_path, mcu, console_output_callback):
    global PROG_PY_PATH, COM_PORT
    if not PROG_PY_PATH or not os.path.exists(PROG_PY_PATH):
        messagebox.showerror("Error", "prog.py path not set or missing")
        return

    if not COM_PORT:
        messagebox.showerror("Error", "CH340 COM port not detected")
        return

    command = [
        sys.executable, PROG_PY_PATH,
        "-t", "uart", "-u", COM_PORT,
        "-b", "57600", "-d", mcu,
        "--fuses", "0:0b00000000", "2:0x01", "6:0x04", "7:0x00", "8:0x00",
        "-f", hex_path, "-a", "write", "-v"
    ]

    try:
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output = ""
        for line in proc.stdout:
            output += line
            console_output_callback(line)
        proc.wait()

        log_device_output(os.path.basename(hex_path), output)

        if "UPDI init failed" in output:
            messagebox.showerror("Error", "UPDI Failed. Reseat the device.")
        elif "Device ID mismatch" in output:
            messagebox.showerror("Error", f"Device ID mismatch. Expected device for MCU {mcu}.")
        elif proc.returncode == 0:
            messagebox.showinfo("Success", "Programming successful")
        else:
            messagebox.showerror("Error", "Programming failed")

    except Exception as e:
        messagebox.showerror("Exception", str(e))

# --- GUI Setup ---
def create_main_gui():
    global COM_PORT
    load_config()
    COM_PORT = detect_ch340_port()

    root = tk.Tk()
    root.title("BreadboarD GeniuS Programmer")
    root.geometry("1200x800")

    top_frame = tk.Frame(root)
    top_frame.pack(fill="x", padx=10, pady=5)

    com_label = tk.Label(top_frame, text=f"COM Port: {COM_PORT if COM_PORT else 'Not found'}")
    com_label.pack(side="left")

    def update_console(text):
        console.insert("end", text)
        console.see("end")

    def add_hex_file(section):
        file_path = filedialog.askopenfilename(filetypes=[("Hex Files", "*.hex")])
        if not file_path:
            return
        name = os.path.splitext(os.path.basename(file_path))[0]
        entry = {"name": name, "path": file_path}
        if section == "logic":
            HEX_LOGIC.append(entry)
        else:
            HEX_COUNTER.append(entry)
        save_config()
        root.destroy()
        create_main_gui()

    def build_section(parent, label, hex_list, mcu):
        tk.Label(parent, text=label, font=("Arial", 14, "bold")).pack(anchor="w", pady=(10, 0))
        for entry in hex_list:
            frame = tk.Frame(parent)
            frame.pack(fill="x", pady=2)
            btn = tk.Button(frame, text=entry["name"], command=lambda e=entry: run_prog_py(e["path"], mcu, update_console))
            btn.pack(side="left")
            rmv = tk.Button(frame, text="X", fg="red", command=lambda e=entry: (hex_list.remove(e), save_config(), root.destroy(), create_main_gui()))
            rmv.pack(side="right")
        tk.Button(parent, text="Add HEX", command=lambda: add_hex_file("logic" if mcu == "attiny1616" else "counter")).pack(pady=5)

    content = tk.Frame(root)
    content.pack(fill="both", expand=True, padx=10, pady=5)

    logic_frame = tk.LabelFrame(content, text="Logic Gates (attiny1616)")
    logic_frame.pack(side="left", fill="both", expand=True, padx=10)
    build_section(logic_frame, "Standard + Custom Logic Files", HEX_LOGIC, "attiny1616")

    counter_frame = tk.LabelFrame(content, text="Counters (atmega4809)")
    counter_frame.pack(side="right", fill="both", expand=True, padx=10)
    build_section(counter_frame, "Standard + Custom Counter Files", HEX_COUNTER, "atmega4809")

    console = tk.Text(root, height=15, bg="black", fg="lime")
    console.pack(fill="both", expand=False, padx=10, pady=10)

    root.mainloop()

if __name__ == "__main__":
    create_main_gui()
