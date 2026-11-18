PLUGIN_ID  := bluetoothBattery
PLUGIN_DIR := $(HOME)/.config/DankMaterialShell/plugins/BluetoothBattery
QML_FILES  := $(wildcard *.qml)

.PHONY: help install uninstall reload status check logs

help:
	@echo "Bluetooth Battery — DankBar plugin"
	@echo ""
	@echo "  make install     symlink this repo into $(PLUGIN_DIR)"
	@echo "  make uninstall   remove that symlink (never touches a real directory)"
	@echo "  make reload      dms ipc call plugins reload $(PLUGIN_ID)"
	@echo "  make status      show the plugin's load state"
	@echo "  make check       validate plugin.json and lint QML when qmllint exists"
	@echo "  make logs        follow the shell's journal"

install:
	@mkdir -p $(dir $(PLUGIN_DIR))
	@if [ -e $(PLUGIN_DIR) ] && [ ! -L $(PLUGIN_DIR) ]; then \
		echo "$(PLUGIN_DIR) exists and is not a symlink; move it aside first" >&2; exit 1; \
	fi
	@ln -sfn $(CURDIR) $(PLUGIN_DIR)
	@echo "installed: $(PLUGIN_DIR) -> $(CURDIR)"

uninstall:
	@if [ -L $(PLUGIN_DIR) ]; then rm $(PLUGIN_DIR); echo "removed $(PLUGIN_DIR)"; \
	else echo "$(PLUGIN_DIR) is not a symlink; leaving it alone"; fi

reload:
	dms ipc call plugins reload $(PLUGIN_ID)

status:
	@dms ipc call plugins list | grep -i $(PLUGIN_ID) || echo "$(PLUGIN_ID) not loaded"

check:
	@python3 -c 'import json; json.load(open("plugin.json"))' && echo "plugin.json: valid"
	@if command -v qmllint >/dev/null 2>&1; then \
		qmllint $(QML_FILES) && echo "qmllint: ok"; \
	else echo "qmllint not installed; QML lint skipped"; fi

logs:
	journalctl --user -u dms -f
