#!/usr/bin/env python3
# Always-on BlueZ pairing agent (NoInputNoOutput), started by i3.
#
# Without a registered agent BlueZ rejects every pairing confirmation and
# every incoming profile connection ("Authentication attempt without agent"
# in `journalctl -u bluetooth`): headphones like the MOMENTUM 4 say "paired"
# but the bond is never stored, so they drop and never auto-connect. The
# `bluetoothctl --agent ... pair` in rofi_bt_battery.sh only lives for a few
# seconds, too short for headsets that come back to open A2DP/HFP.
#
# Policy: "just works" pairing is accepted (only possible while we initiate
# a pairing or the adapter is pairable); service authorization is granted
# only to devices that are already paired or trusted.

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

BUS = "org.bluez"
AGENT_PATH = "/dotfiles/bt_agent"
CAPABILITY = "NoInputNoOutput"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


def dev_props(bus, path):
    obj = bus.get_object(BUS, path)
    return dbus.Interface(obj, "org.freedesktop.DBus.Properties")


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus

    def _trust(self, device):
        try:
            dev_props(self.bus, device).Set("org.bluez.Device1", "Trusted", True)
        except dbus.DBusException:
            pass

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        p = dev_props(self.bus, device)
        if p.Get("org.bluez.Device1", "Paired") or p.Get("org.bluez.Device1", "Trusted"):
            return
        raise Rejected("device not paired")

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        self._trust(device)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        self._trust(device)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        return "0000"

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        return dbus.UInt32(0)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        pass


def register(bus):
    try:
        mgr = dbus.Interface(bus.get_object(BUS, "/org/bluez"), "org.bluez.AgentManager1")
        try:
            mgr.RegisterAgent(AGENT_PATH, CAPABILITY)
        except dbus.DBusException as e:
            if "AlreadyExists" not in str(e):
                raise
        mgr.RequestDefaultAgent(AGENT_PATH)
        print("bt_agent: registered as default agent", flush=True)
    except dbus.DBusException as e:
        print(f"bt_agent: bluetoothd not ready ({e.get_dbus_name()})", flush=True)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    Agent(bus)
    register(bus)
    # re-register whenever bluetoothd (re)starts
    bus.add_signal_receiver(
        lambda name, old, new: new and register(bus),
        signal_name="NameOwnerChanged",
        dbus_interface="org.freedesktop.DBus",
        arg0=BUS,
    )
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
