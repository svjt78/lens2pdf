enum ShareProfile { standard, compact }

extension ShareProfileLabel on ShareProfile {
  String get label {
    switch (this) {
      case ShareProfile.standard:
        return 'Standard';
      case ShareProfile.compact:
        return 'Compact';
    }
  }
}
