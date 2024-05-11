class SourceEntity {
  final String owner;
  final String repo;
  final String commitHash;
  final String license;
  final bool explicitVersion;
  final DateTime installedAt;

  String get appID => '$owner/$repo';

  factory SourceEntity.fromMap(Map<String, dynamic> map) {
    return SourceEntity(
      owner: map['owner'],
      repo: map['repo'],
      commitHash: map['commitHash'],
      license: map['license'] ?? "Unknown",
      explicitVersion: map['explicit_version'] ?? false,
      installedAt: DateTime.parse(map['packageInstalledAt']),
    );
  }

  SourceEntity({
    required this.owner,
    required this.repo,
    required this.commitHash,
    required this.license,
    required this.installedAt,
    this.explicitVersion = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'owner': owner,
      'repo': repo,
      'commitHash': commitHash,
      'license': license,
      'packageInstalledAt': installedAt.toString(),
      'explicit_version': explicitVersion,
    };
  }
}
