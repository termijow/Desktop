import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

const DBusInterface = Gio.DBusInterfaceInfo.new_for_xml(`
<node>
  <interface name="org.gnome.Shell.Extensions.DevModeTiler">
    <method name="Tile">
      <arg type="b" direction="out" />
      <arg type="as" direction="out" />
    </method>
  </interface>
</node>
`);

export default class AiStatusExtension extends Extension {
    enable() {
        this._indicator = new PanelMenu.Button(0.5, 'AiStatusIndicator', false);
        
        // Label para la barra superior
        this._label = new St.Label({
            text: '',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'ai-status-label'
        });
        
        this._label.set_style('color: #ff5555; font-weight: bold; padding: 0 10px;');
        this._indicator.add_child(this._label);
        
        // Agregar a la sección central de la barra de estado (cerca del reloj)
        Main.panel.addToStatusArea('ai-status-indicator', this._indicator, 1, 'center');
        
        // Archivos para estado, foco y comando de paste
        this._statusFile = Gio.File.new_for_path('/tmp/ai_status.txt');
        this._pasteFile = Gio.File.new_for_path('/tmp/ai_paste.txt');
        
        // Crear dispositivo de teclado virtual para simular pegado en Wayland
        try {
            const seat = Clutter.get_default_backend().get_default_seat();
            this._virtualDevice = seat.create_virtual_device(Clutter.InputDeviceType.KEYBOARD_DEVICE);
        } catch (e) {
            console.error('[AI Voice Extension] Error creando teclado virtual:', e);
        }

        // Inicializar archivos
        this._updateStatus();
        this._writeFocusedWindow();
        this._clearPasteFile();

        // Monitorear el archivo de estado
        try {
            this._monitorStatus = this._statusFile.monitor_file(Gio.FileMonitorFlags.NONE, null);
            this._monitorStatusId = this._monitorStatus.connect('changed', (monitor, file, otherFile, eventType) => {
                if (eventType === Gio.FileMonitorEvent.CHANGED || eventType === Gio.FileMonitorEvent.CREATED) {
                    this._updateStatus();
                }
            });
        } catch (e) {
            console.error('[AI Voice Extension] Error monitoreando estado:', e);
        }

        // Monitorear el archivo de paste
        try {
            this._monitorPaste = this._pasteFile.monitor_file(Gio.FileMonitorFlags.NONE, null);
            this._monitorPasteId = this._monitorPaste.connect('changed', (monitor, file, otherFile, eventType) => {
                if (eventType === Gio.FileMonitorEvent.CHANGED || eventType === Gio.FileMonitorEvent.CREATED) {
                    this._checkPasteCommand();
                }
            });
        } catch (e) {
            console.error('[AI Voice Extension] Error monitoreando paste:', e);
        }

        // Monitorear cambios de ventana activa
        this._focusWindowId = global.display.connect('notify::focus-window', () => {
            this._writeFocusedWindow();
        });

        // Iniciar bucle de sondeo para detectar sacudida del ratón (shake to launch)
        try {
            this._pollId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 40, () => {
                try {
                    let [x, y] = global.get_pointer();
                    this._handlePointerCoords(x, y);
                } catch (e) {
                    console.error('[AI Voice Extension] Error en bucle de puntero:', e);
                }
                return GLib.SOURCE_CONTINUE;
            });
        } catch (e) {
            console.error('[AI Voice Extension] Error registrando sondeo de mouse:', e);
        }
    }
    
    disable() {
        if (this._monitorStatusId) {
            this._monitorStatus.disconnect(this._monitorStatusId);
            this._monitorStatusId = null;
        }
        if (this._monitorStatus) {
            this._monitorStatus.cancel();
            this._monitorStatus = null;
        }
        if (this._monitorPasteId) {
            this._monitorPaste.disconnect(this._monitorPasteId);
            this._monitorPasteId = null;
        }
        if (this._monitorPaste) {
            this._monitorPaste.cancel();
            this._monitorPaste = null;
        }
        if (this._focusWindowId) {
            global.display.disconnect(this._focusWindowId);
            this._focusWindowId = null;
        }
        if (this._pollId) {
            try {
                GLib.Source.remove(this._pollId);
            } catch (e) {
                // Ignorar
            }
            this._pollId = null;
        }
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
        this._label = null;
        this._statusFile = null;
        this._pasteFile = null;
        this._virtualDevice = null;
    }
    
    _updateStatus() {
        try {
            if (this._statusFile.query_exists(null)) {
                let [success, contents] = this._statusFile.load_contents(null);
                if (success) {
                    let text = new TextDecoder('utf-8').decode(contents).trim();
                    if (text.length > 0) {
                        this._label.set_text(text);
                        this._indicator.show();
                        
                        if (text.includes('🔴') || text.includes('Grabando')) {
                            this._label.set_style('color: #ff5555; font-weight: bold; padding: 0 10px;');
                        } else if (text.includes('✍️') || text.includes('Transcribiendo')) {
                            this._label.set_style('color: #f1fa8c; font-weight: bold; padding: 0 10px;');
                        } else if (text.includes('🤖') || text.includes('Pensando')) {
                            this._label.set_style('color: #50fa7b; font-weight: bold; padding: 0 10px;');
                        } else if (text.includes('⚙️') || text.includes('Ejecutando')) {
                            this._label.set_style('color: #ff79c6; font-weight: bold; padding: 0 10px;');
                        } else {
                            this._label.set_style('color: #8be9fd; font-weight: bold; padding: 0 10px;');
                        }
                    } else {
                        this._indicator.hide();
                    }
                } else {
                    this._indicator.hide();
                }
            } else {
                this._indicator.hide();
            }
        } catch (e) {
            this._indicator.hide();
        }
    }

    _writeFocusedWindow() {
        try {
            let win = global.display.focus_window;
            let details = {
                class: '',
                title: '',
                pid: 0
            };
            if (win) {
                details.class = win.get_wm_class() || '';
                details.title = win.get_title() || '';
                details.pid = win.get_pid() || 0;
            }
            
            let file = Gio.File.new_for_path('/tmp/ai_focused_window.json');
            let data = JSON.stringify(details);
            file.replace_contents(
                new TextEncoder().encode(data),
                null,
                false,
                Gio.FileCreateFlags.REPLACE_DESTINATION,
                null
            );
        } catch (e) {
            console.error('[AI Voice Extension] Error escribiendo info de ventana:', e);
        }
    }

    _clearPasteFile() {
        try {
            this._pasteFile.replace_contents(
                '\n',
                null,
                false,
                Gio.FileCreateFlags.REPLACE_DESTINATION,
                null
            );
        } catch (e) {
            // Ignorar
        }
    }

    _checkPasteCommand() {
        try {
            if (this._pasteFile.query_exists(null)) {
                let [success, contents] = this._pasteFile.load_contents(null);
                if (success) {
                    let cmd = new TextDecoder('utf-8').decode(contents).trim();
                    if (cmd.length > 0) {
                        // Limpiar el archivo primero para evitar bucles
                        this._clearPasteFile();
                        
                        // Procesar el pegado
                        if (cmd === 'paste') {
                            this._simulatePaste(false);
                        } else if (cmd === 'paste_terminal') {
                            this._simulatePaste(true);
                        } else if (cmd === 'tile') {
                            this.Tile();
                        }
                    }
                }
            }
        } catch (e) {
            console.error('[AI Voice Extension] Error procesando comando de paste:', e);
        }
    }

    _simulatePaste(isTerminal) {
        if (!this._virtualDevice) return;
        
        try {
            const now = () => GLib.get_monotonic_time() / 1000;
            let t = now();
            
            if (isTerminal) {
                // Ctrl + Shift + V
                this._virtualDevice.notify_keyval(t, Clutter.KEY_Control_L, Clutter.KeyState.PRESSED);
                this._virtualDevice.notify_keyval(t + 10, Clutter.KEY_Shift_L, Clutter.KeyState.PRESSED);
                this._virtualDevice.notify_keyval(t + 20, Clutter.KEY_v, Clutter.KeyState.PRESSED);
                this._virtualDevice.notify_keyval(t + 30, Clutter.KEY_v, Clutter.KeyState.RELEASED);
                this._virtualDevice.notify_keyval(t + 40, Clutter.KEY_Shift_L, Clutter.KeyState.RELEASED);
                this._virtualDevice.notify_keyval(t + 50, Clutter.KEY_Control_L, Clutter.KeyState.RELEASED);
            } else {
                // Ctrl + V
                this._virtualDevice.notify_keyval(t, Clutter.KEY_Control_L, Clutter.KeyState.PRESSED);
                this._virtualDevice.notify_keyval(t + 10, Clutter.KEY_v, Clutter.KeyState.PRESSED);
                this._virtualDevice.notify_keyval(t + 20, Clutter.KEY_v, Clutter.KeyState.RELEASED);
                this._virtualDevice.notify_keyval(t + 30, Clutter.KEY_Control_L, Clutter.KeyState.RELEASED);
            }
        } catch (e) {
            console.error('[AI Voice Extension] Error simulando teclas:', e);
        }
    }

    Tile() {
        try {
            let display = global.display;
            let monitors_count = display.get_n_monitors();
            
            let windows = global.get_window_actors().map(a => a.meta_window);
            
            let braveWin = null;
            let codeWin = null;
            let termWin = null;
            
            for (let win of windows) {
                if (!win) continue;
                let wm_class = win.get_wm_class() || "";
                wm_class = wm_class.toLowerCase();
                let title = win.get_title() || "";
                title = title.toLowerCase();
                
                if (wm_class.includes("brave")) {
                    braveWin = win;
                } else if (wm_class.includes("code") || title.includes("visual studio code")) {
                    codeWin = win;
                } else if (wm_class.includes("blackbox") || wm_class.includes("terminal") || wm_class.includes("kitty") || wm_class.includes("alacritty") || wm_class.includes("console")) {
                    termWin = win;
                }
            }
            
            let launched_any = false;
            
            if (!braveWin) {
                Gio.AppInfo.create_from_commandline("brave", null, Gio.AppInfoCreateFlags.NONE).launch([], null);
                launched_any = true;
            }
            if (!codeWin) {
                Gio.AppInfo.create_from_commandline("code", null, Gio.AppInfoCreateFlags.NONE).launch([], null);
                launched_any = true;
            }
            if (!termWin) {
                Gio.AppInfo.create_from_commandline("flatpak run com.raggesilver.BlackBox", null, Gio.AppInfoCreateFlags.NONE).launch([], null);
                launched_any = true;
            }
            
            if (launched_any) {
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
                    this.Tile();
                    return GLib.SOURCE_REMOVE;
                });
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => {
                    this.Tile();
                    return GLib.SOURCE_REMOVE;
                });
                return [true, []];
            }
            
            let primary_idx = display.get_primary_monitor();
            let monitorBrave = primary_idx;
            let monitorDev = primary_idx;
            
            for (let i = 0; i < monitors_count; i++) {
                if (i !== primary_idx) {
                    monitorDev = i;
                    break;
                }
            }
            
            let rectBrave = display.get_monitor_geometry(monitorBrave);
            let rectDev = display.get_monitor_geometry(monitorDev);
            
            if (braveWin) {
                braveWin.unmaximize(Meta.MaximizeFlags.BOTH);
                braveWin.move_resize_frame(true, rectBrave.x, rectBrave.y, rectBrave.width, rectBrave.height);
                braveWin.maximize(Meta.MaximizeFlags.BOTH);
                braveWin.activate(global.get_current_time());
            }
            
            if (codeWin) {
                codeWin.unmaximize(Meta.MaximizeFlags.BOTH);
                let w = Math.floor(rectDev.width / 2);
                codeWin.move_resize_frame(true, rectDev.x, rectDev.y, w, rectDev.height);
                codeWin.activate(global.get_current_time());
            }
            
            if (termWin) {
                termWin.unmaximize(Meta.MaximizeFlags.BOTH);
                let w = Math.floor(rectDev.width / 2);
                let x = rectDev.x + w;
                termWin.move_resize_frame(true, x, rectDev.y, w, rectDev.height);
                termWin.activate(global.get_current_time());
            }
            
            return [true, []];
        } catch (e) {
            console.error('[AI Voice Extension] Error en DevModeTiler Tile:', e);
            return [false, []];
        }
    }

    _handlePointerCoords(x, y) {
        try {
            let now = GLib.get_monotonic_time() / 1000; // milisegundos

            if (this._lastX === undefined || this._lastY === undefined) {
                this._lastX = x;
                this._lastY = y;
                this._switchX = x;
                this._lastDirection = 0;
                this._lastSwitchTime = now;
                this._shakeCount = 0;
                return;
            }

            let dx = x - this._lastX;
            // Ignorar pequeños ruidos o movimientos microscópicos
            if (Math.abs(dx) < 4) {
                return;
            }

            let dir = dx > 0 ? 1 : -1;

            if (this._lastDirection !== 0 && dir !== this._lastDirection) {
                let sweepDist = Math.abs(x - this._switchX);
                
                // Si el barrido horizontal acumulado es de al menos 90 píxeles
                if (sweepDist > 90) {
                    let timeDiff = now - this._lastSwitchTime;
                    
                    // Si el cambio de sentido ocurrió rápido (menos de 450ms)
                    if (timeDiff < 450) {
                        this._shakeCount++;
                        if (this._shakeCount >= 3) {
                            this._shakeCount = 0;
                            this._triggerLauncher();
                        }
                    } else {
                        this._shakeCount = 0;
                    }
                    
                    this._lastSwitchTime = now;
                    this._switchX = x;
                }
                
                this._lastDirection = dir;
            } else if (this._lastDirection === 0) {
                this._lastDirection = dir;
                this._switchX = x;
                this._lastSwitchTime = now;
            }

            this._lastX = x;
            this._lastY = y;
        } catch (e) {
            console.error('[AI Voice Extension] Error procesando coordenadas de puntero:', e);
        }
    }

    _triggerLauncher() {
        try {
            let now = GLib.get_monotonic_time() / 1000;
            if (this._lastLaunchTime && (now - this._lastLaunchTime < 1500)) {
                return;
            }
            this._lastLaunchTime = now;
            
            // Lanzar el script de launcher.py de forma asíncrona
            Gio.AppInfo.create_from_commandline(
                "python3 /home/termihoe/Documents/Desktop/voice-assistant/launcher.py",
                null,
                Gio.AppInfoCreateFlags.NONE
            ).launch([], null);
        } catch (e) {
            console.error('[AI Voice Extension] Error lanzando launcher desde sacudida:', e);
        }
    }
}
