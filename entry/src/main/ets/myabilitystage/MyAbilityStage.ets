/**
 * Custom AbilityStage for the codelab entry HAP.
 * Demonstrates AbilityStageContext by reading module-level information
 * that is available before any UIAbility is created.
 *
 * This class must be registered as srcEntry in module.json5.
 *
 * Target APIs demonstrated:
 *   - AbilityStage.onCreate()
 *   - AbilityStageContext (this.context)
 *   - AbilityStageContext.currentHapModuleInfo.name
 *   - AbilityStageContext.config.language
 */
import { AbilityStage } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Constants } from '../constants/Constants';

export default class MyAbilityStage extends AbilityStage {

  /**
   * onCreate() is called when the HAP is loaded into the process for the
   * first time — before any UIAbility or ExtensionAbility in this module
   * is created. This makes it the ideal place for module-level initialization.
   *
   * this.context is an AbilityStageContext instance.
   * It provides:
   *   - currentHapModuleInfo: metadata about this HAP module
   */
  onCreate(): void {
    const moduleName: string =
      this.context.currentHapModuleInfo?.name ?? Constants.PLACEHOLDER_UNKNOWN;
    const language: string =
      this.context.config?.language ?? Constants.PLACEHOLDER_UNKNOWN;

    hilog.info(
      Constants.LOG_DOMAIN,
      Constants.LOG_TAG,
      'AbilityStage onCreate — module: %{public}s, language: %{public}s',
      moduleName,
      language
    );
    AppStorage.setOrCreate<string>(Constants.KEY_MODULE_NAME, moduleName);
  }

  onDestroy(): void {
    hilog.info(
      Constants.LOG_DOMAIN,
      Constants.LOG_TAG,
      'AbilityStage onDestroy'
    );
  }
}
