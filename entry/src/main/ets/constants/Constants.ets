export class Constants {
  static readonly LOG_DOMAIN: number = 0x0001;
  static readonly LOG_TAG: string = 'LifecycleContext';
  static readonly KEY_MODULE_NAME: string = 'moduleName';
  /** Current area mode as a display string (e.g. "EL1" or "EL2") */
  static readonly KEY_AREA_MODE: string = 'areaMode';
  static readonly KEY_STAGE_MODE: string = 'stageMode';
  static readonly KEY_WORKER_PATH: string = 'workerPath';
  static readonly KEY_LIFECYCLE_LOG: string = 'lifecycleLog';


  static readonly WORKER_ENTRY: string = 'entry/ets/workers/ContextWorker.ets';
  /** Context type tag sent alongside the SendableContext */
  static readonly CONTEXT_TAG_BASE: string = 'BaseContext';
  static readonly WORKER_MSG_PREFIX: string = 'databaseDir:';

  static readonly AREA_EL1_LABEL: string = 'EL1';
  static readonly AREA_EL2_LABEL: string = 'EL2';

  static readonly PLACEHOLDER_PENDING: string = 'Pending...';
  static readonly PLACEHOLDER_UNKNOWN: string = 'Unknown';
}
