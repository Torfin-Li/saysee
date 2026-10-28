import Foundation

/// Delete obsolete provider metadata without reading or opening its credential file.
public enum LegacySettingsMigration {
 public static let keys=["provider","credentials","project","location","vertexModel"]
 public static func remove(from defaults:UserDefaults) {
  for key in keys {defaults.removeObject(forKey:key)}
 }
}
