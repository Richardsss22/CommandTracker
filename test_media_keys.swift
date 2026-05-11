import AppKit

let HIDPostAuxKey = 8
let key = 0 // Volume Up
let evtDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: 0xA00), timestamp: 0, windowNumber: 0, context: nil, subtype: Int16(HIDPostAuxKey), data1: Int((key << 16) | ((0xa) << 8)), data2: -1)
let evtUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: 0xB00), timestamp: 0, windowNumber: 0, context: nil, subtype: Int16(HIDPostAuxKey), data1: Int((key << 16) | ((0xb) << 8)), data2: -1)

evtDown?.cgEvent?.post(tap: .cghidEventTap)
evtUp?.cgEvent?.post(tap: .cghidEventTap)
print("Enviado Volume Up")
