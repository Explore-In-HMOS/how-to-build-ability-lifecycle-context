/**
 * A @Sendable class that wraps a SendableContext so it can be passed
 * by reference across thread boundaries to a Worker thread.
 *
 * Key rule: The Context type used in convertFromContext on the main thread
 * must match the convert* call used in the Worker thread.
 * Here we pass a base Context → Worker calls convertToContext (base).
 *
 * Target APIs demonstrated:
 *   - SendableContext (type)
 *   - @Sendable decorator
 */
import { sendableContextManager } from '@kit.AbilityKit';

@Sendable
export class SendableObject {

  sendableContext: sendableContextManager.SendableContext;
  contextName: string;

  constructor(
    sendableContext: sendableContextManager.SendableContext,
    contextName: string
  ) {
    this.sendableContext = sendableContext;
    this.contextName = contextName;
  }
}
