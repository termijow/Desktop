#!/usr/bin/env python3
import os
import sys
import subprocess
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

HISTORY_FILE = os.path.expanduser("~/.config/voice-assistant-launcher-history.txt")

class LauncherWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Asistente IA")
        self.set_default_size(600, 50)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_decorated(False)  # Sin bordes para aspecto limpio estilo Krunner/Spotlight
        self.set_keep_above(True)
        self.set_border_width(8)
        self.set_resizable(False)

        # Cargar historial de comandos
        self.history = self.load_history()
        self.history_index = len(self.history)
        self.current_input_save = ""

        # Tema Oscuro Catppuccin
        css = b"""
        window {
            background-color: #1e1e2e;
            border: 2px solid #45475a;
            border-radius: 12px;
        }
        entry {
            background-color: #313244;
            color: #cdd6f4;
            border: 1px solid #45475a;
            border-radius: 8px;
            padding: 12px;
            font-size: 16px;
            font-family: 'Outfit', 'Inter', sans-serif;
        }
        entry:focus {
            border-color: #cba6f7;
        }
        """
        style_provider = Gtk.CssProvider()
        style_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.add(vbox)

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("¿Qué quieres que haga?...")
        self.entry.connect("activate", self.on_execute)
        self.entry.connect("key-press-event", self.on_key_press)
        vbox.pack_start(self.entry, True, True, 0)

        # Cerrar automáticamente al perder el foco
        self.connect("focus-out-event", lambda w, e: self.close_launcher())

    def load_history(self):
        if os.path.exists(HISTORY_FILE):
            try:
                with open(HISTORY_FILE, "r", encoding="utf-8") as f:
                    return [line.strip() for line in f if line.strip()]
            except Exception:
                return []
        return []

    def save_history(self, text):
        if not text:
            return
        if self.history and self.history[-1] == text:
            return
        self.history.append(text)
        try:
            os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
            with open(HISTORY_FILE, "a", encoding="utf-8") as f:
                f.write(text + "\n")
        except Exception as e:
            print(f"Error guardando historial: {e}")

    def on_execute(self, entry):
        text = self.entry.get_text().strip()
        if text:
            self.save_history(text)
            self.execute_command(text)
        self.close_launcher()

    def execute_command(self, text):
        script_path = os.path.expanduser("~/Documents/Desktop/voice-assistant/assistant.py")
        # Ejecuta la acción en segundo plano
        subprocess.Popen(["python3", script_path, "--mode", "ai", "--text", text])

    def close_launcher(self):
        Gtk.main_quit()
        sys.exit(0)

    def on_key_press(self, widget, event):
        # Escape cierra la ventana
        if event.keyval == Gdk.KEY_Escape:
            self.close_launcher()
            return True
            
        # Flecha arriba: comando anterior en el historial
        elif event.keyval == Gdk.KEY_Up:
            if self.history_index > 0:
                if self.history_index == len(self.history):
                    self.current_input_save = self.entry.get_text()
                self.history_index -= 1
                self.entry.set_text(self.history[self.history_index])
                self.entry.set_position(-1) # Cursor al final
            return True
            
        # Flecha abajo: siguiente comando en el historial
        elif event.keyval == Gdk.KEY_Down:
            if self.history_index < len(self.history) - 1:
                self.history_index += 1
                self.entry.set_text(self.history[self.history_index])
                self.entry.set_position(-1)
            elif self.history_index == len(self.history) - 1:
                self.history_index += 1
                self.entry.set_text(self.current_input_save)
                self.entry.set_position(-1)
            return True
            
        return False

if __name__ == "__main__":
    win = LauncherWindow()
    win.show_all()
    win.present()
    Gtk.main()
