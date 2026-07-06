/**
 * EntryAbility.ets
 *
 * The main UIAbility. Demonstrates the full Stage model
 * UIAbility lifecycle and the complete context hierarchy.
 *
 * AppStorage key management rule applied throughout:
 *   - AppStorage.setOrCreate()  → use ONLY for the very first write of a key
 *   - AppStorage.set()          → use for ALL subsequent updates to an existing key
 *   setOrCreate on an already-existing key is a silent no-op and will NOT
 *   update the value or notify subscribers.
 *
 * Target APIs demonstrated:
 *   - UIAbility.onCreate()
 *   - UIAbility.onForeground()
 *   - UIAbility.onBackground()
 *   - UIAbility.onDestroy()
 *   - UIAbility.onWindowStageCreate()
 *   - BaseContext.stageMode
 *   - sendableContextManager.convertFromContext()
 *   - contextConstant.AreaMode
 */
import { AbilityConstant, contextConstant, sendableContextManager, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ErrorEvent, MessageEvents, worker } from '@kit.ArkTS';
import { Constants } from '../constants/Constants';
import { SendableObject } from '../model/SendableObject';

export default class EntryAbility extends UIAbility {

  private workerInstance: worker.ThreadWorker | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onCreate');
    const stageMode: boolean = this.context.stageMode;
    AppStorage.setOrCreate<string>(Constants.KEY_STAGE_MODE, String(stageMode));
    this.context.area = contextConstant.AreaMode.EL2;
    AppStorage.setOrCreate<string>(Constants.KEY_AREA_MODE, Constants.AREA_EL2_LABEL);
    AppStorage.setOrCreate<string[]>(Constants.KEY_LIFECYCLE_LOG, []);
    this.appendLifecycleEvent('onCreate');
    this.spawnWorkerAndSendContext();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(
          Constants.LOG_DOMAIN, Constants.LOG_TAG,
          'loadContent failed, code: %{public}d, msg: %{public}s',
          err.code, err.message
        );
      }
    });
  }

  onForeground(): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onForeground');
    this.appendLifecycleEvent('onForeground');
  }

  onBackground(): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onBackground');
    this.appendLifecycleEvent('onBackground');
  }

  onWindowStageDestroy(): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'EntryAbility onDestroy');
    this.appendLifecycleEvent('onDestroy');
    this.workerInstance?.terminate();
    this.workerInstance = undefined;
  }

  /**
   * Pattern:
   *   1. Read the current array via AppStorage.get()
   *   2. Create a new array with the new event appended
   *   3. Write back via AppStorage.set() — NOT setOrCreate()
   */
  private appendLifecycleEvent(eventName: string): void {
    const existing: string[] =
      AppStorage.get<string[]>(Constants.KEY_LIFECYCLE_LOG) ?? [];
    const updated: string[] = [...existing, eventName];
    const ok: boolean = AppStorage.set<string[]>(Constants.KEY_LIFECYCLE_LOG, updated);
    hilog.info(
      Constants.LOG_DOMAIN, Constants.LOG_TAG,
      'appendLifecycleEvent: %{public}s (set result: %{public}s)',
      eventName, String(ok)
    );
  }

  /**
   * Creates a Worker thread and sends the current context as a SendableContext.
   * Demonstrates:
   *   - sendableContextManager.convertFromContext()
   *   - SendableObject (@Sendable wrapper)
   *   - worker.postMessageWithSharedSendable()
   */
  private spawnWorkerAndSendContext(): void {
    try {
      this.workerInstance = new worker.ThreadWorker(Constants.WORKER_ENTRY);

      this.workerInstance.onmessage = (e: MessageEvents): void => {
        const msg: string = e.data as string;
        hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG,
          'Main thread received from Worker: %{public}s', msg);

        if (msg.startsWith(Constants.WORKER_MSG_PREFIX)) {
          const path: string = msg.substring(Constants.WORKER_MSG_PREFIX.length);
          AppStorage.setOrCreate<string>(Constants.KEY_WORKER_PATH, path);
        }
      };

      this.workerInstance.onerror = (e: ErrorEvent): void => {
        hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG,
          'Worker error on main side: %{public}s', e.message);
      };

      const sendableCtx: sendableContextManager.SendableContext =
        sendableContextManager.convertFromContext(this.context);

      const payload: SendableObject = new SendableObject(
        sendableCtx,
        Constants.CONTEXT_TAG_BASE
      );

      this.workerInstance.postMessageWithSharedSendable(payload);
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, 'SendableContext posted to Worker');

    } catch (err) {
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG,
        'spawnWorkerAndSendContext failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate<string>(Constants.KEY_WORKER_PATH, Constants.PLACEHOLDER_UNKNOWN);
    }
  }
}
