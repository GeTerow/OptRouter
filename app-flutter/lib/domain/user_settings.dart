class UserSettings {
  const UserSettings({
    this.defaultOrigin = '',
    this.defaultDestination = '',
  });

  final String defaultOrigin;
  final String defaultDestination;

  bool get hasDefaults =>
      defaultOrigin.trim().isNotEmpty || defaultDestination.trim().isNotEmpty;
}
