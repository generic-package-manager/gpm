import '../../entity/asset_entity.dart';
import '../provider/compatible_asset_provider.dart';
import 'installation_service.dart';

class UpdateService {
  UpdateService._();

  static Future<bool> initReleaseUpdate(
    String repo,
    CompatibleReleaseAssetProvider provider,
    List<String> extensions,
    ReleaseAssetEntity current,
    bool explicitCall,
  ) async {
    // identifying target type
    List<ReleaseAssetEntity> assets = [];
    if (current.type == 'primary') {
      assets.addAll(provider.primary);
    } else if (current.type == 'secondary') {
      assets.addAll(provider.secondary);
    } else {
      assets.addAll(provider.others);
    }

    // self-chosing target release
    int index = current.index;

    // checking availablity
    bool available = index >= 0 && index < assets.length;
    if (available) {
      // going for update
      ReleaseAssetEntity target = assets[index];
      // the install service will do the rest
      await InstallationService.downloadRelease(target, explicitCall);
    }

    return available;
  }
}
