/**
 * A Worker thread that demonstrates the receiving side of the
 * sendableContextManager API.
 *
 * Flow:
 *   1. Main thread converts UIAbilityContext → SendableContext
 *      via sendableContextManager.convertFromContext()
 *   2. Main thread wraps it in a SendableObject and calls
 *      worker.postMessageWithSharedSendable(sendableObject)
 *   3. This Worker receives the SendableObject in onmessage
 *   4. Worker calls sendableContextManager.convertToContext()
 *      to recover a usable Context instance
 *   5. Worker reads context.databaseDir and posts it back
 *      to the main thread as a plain string message
 *
 * Target APIs demonstrated:
 *   - sendableContextManager.convertToContext()
 *   - SendableContext (type)
 *   - Worker thread lifecycle (onmessage, postMessage, onerror)
 */
import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { SendableObject } from '../model/SendableObject';
import { Constants } from '../constants/Constants';

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
workerPort.onmessage = (e: MessageEvents): void => {
  const sendableObject: SendableObject = e.data as SendableObject;
  const sendableContext: sendableContextManager.SendableContext = sendableObject.sendableContext;

  hilog.info(
    Constants.LOG_DOMAIN,
    Constants.LOG_TAG,
    'Worker received context tag: %{public}s',
    sendableObject.contextName
  );

  try {
    const context: common.Context = sendableContextManager.convertToContext(sendableContext);0
    const dbDir: string = context.databaseDir ?? Constants.PLACEHOLDER_UNKNOWN;

    hilog.info(
      Constants.LOG_DOMAIN,
      Constants.LOG_TAG,
      'Worker resolved databaseDir: %{public}s',
      dbDir
    );
    workerPort.postMessage(Constants.WORKER_MSG_PREFIX + dbDir);

  } catch (err) {
    hilog.error(
      Constants.LOG_DOMAIN,
      Constants.LOG_TAG,
      'Worker convertToContext failed: %{public}s',
      JSON.stringify(err)
    );
    workerPort.postMessage(Constants.WORKER_MSG_PREFIX + Constants.PLACEHOLDER_UNKNOWN);
  }
};

workerPort.onmessageerror = (e: MessageEvents): void => {
  hilog.error(
    Constants.LOG_DOMAIN,
    Constants.LOG_TAG,
    'Worker onmessageerror: %{public}s',
    JSON.stringify(e)
  );
};

workerPort.onerror = (e: ErrorEvent): void => {
  hilog.error(
    Constants.LOG_DOMAIN,
    Constants.LOG_TAG,
    'Worker onerror: %{public}s',
    e.message
  );
};
