final class OSKeywords {
  OSKeywords._();

  static final windows = ['win', 'windows'];
  static final macos = ['mac', 'macos'];
  static final linux = ['linux', 'amd64'];
  static final debian = ['deb', ...linux];
  static final fedora = ['rpm', ...linux];
  static final arch = ['arch', ...linux];
  static final unrecognized = <String>[];
}
