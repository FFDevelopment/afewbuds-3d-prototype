"""AFewBuds desktop launcher. Packaged as a standalone Windows executable."""
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox
from updater import Updater, InstanceLock, AlreadyRunning


def main():
    root = tk.Tk()
    root.title('AFewBuds')
    root.geometry('460x220')
    root.resizable(False, False)
    root.configure(bg='#101b15')
    root.update_idletasks()
    root.geometry(f'+{(root.winfo_screenwidth()-460)//2}+{(root.winfo_screenheight()-220)//2}')
    tk.Label(root, text='AFEWBUDS', fg='#8de466', bg='#101b15', font=('Segoe UI', 26, 'bold')).pack(pady=(24, 10))
    status = tk.StringVar(value='Checking for updates…')
    tk.Label(root, textvariable=status, fg='#e7eee5', bg='#101b15', wraplength=425, font=('Segoe UI', 11)).pack()
    bar = ttk.Progressbar(root, length=410, mode='determinate')
    bar.pack(pady=16)
    buttons = tk.Frame(root, bg='#101b15'); buttons.pack()
    home = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local')) / 'AFewBudsLauncher'
    try:
        lock = InstanceLock(home)
    except AlreadyRunning as exc:
        messagebox.showinfo('AFewBuds', str(exc)); root.destroy(); return
    updater, events = Updater(home), queue.Queue()
    busy, child_running = False, False

    def report(text, progress):
        events.put(('progress', text, progress))

    def worker(installed=False):
        try:
            exe = updater.installed() if installed else updater.prepare(report)
            if not exe:
                raise RuntimeError('No verified game is installed yet. Connect to the internet and retry.')
            report('Starting AFewBuds…', 1)
            # Embedded game uses the existing Godot custom save directory, never the install path.
            process = subprocess.Popen([str(exe)], cwd=exe.parent)
            events.put(('launched',))
            started = time.monotonic()
            code = process.wait()
            if code and time.monotonic()-started < 15:
                recovered = updater.rollback()
                raise RuntimeError('The game could not start.' + (' The previous build has been restored; choose Play installed to use it.' if recovered else ' Please retry or contact support.'))
            events.put(('done',))
        except Exception as exc:
            events.put(('error', str(exc)))

    def start(installed=False):
        nonlocal busy
        if busy: return
        busy = True
        for widget in buttons.winfo_children(): widget.destroy()
        threading.Thread(target=worker, args=(installed,), daemon=True).start()

    def poll():
        nonlocal busy, child_running
        try:
            while True:
                event = events.get_nowait()
                if event[0] == 'progress': status.set(event[1]); bar['value'] = event[2] * 100
                elif event[0] == 'launched': child_running = True; root.withdraw()
                elif event[0] == 'done': root.destroy(); return
                elif event[0] == 'error':
                    busy = child_running = False
                    root.deiconify(); status.set('Unable to update or start the game.')
                    bar['value'] = 0
                    ttk.Button(buttons, text='Retry update', command=start).pack(side='left', padx=6)
                    if updater.installed(): ttk.Button(buttons, text='Play installed', command=lambda: start(True)).pack(side='left', padx=6)
                    messagebox.showwarning('AFewBuds', event[1], parent=root)
        except queue.Empty:
            pass
        root.after(80, poll)

    def close():
        if busy:
            status.set('Please wait for the update to finish.'); return
        root.destroy()

    root.protocol('WM_DELETE_WINDOW', close)
    if '--ui-smoke' in sys.argv:
        root.after(300, root.destroy)
    else:
        start(); root.after(80, poll)
    try:
        root.mainloop()
    finally:
        lock.close()

if __name__ == '__main__':
    main()
