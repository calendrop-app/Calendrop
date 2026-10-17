import Foundation

extension LocalizedStringResource.BundleDescription {
  /// CalendropCore's own String Catalog, which the app bundle carries as a resource
  /// bundle of its own.
  static var core: Self { .atURL(Bundle.module.bundleURL) }
}
