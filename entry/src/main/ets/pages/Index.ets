import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics, CircleShape } from '@kit.ArkUI';
import { common, contextConstant, sendableContextManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MessageEvents, worker } from '@kit.ArkTS';
import { Constants } from '../constants/Constants';
import { SendableObject } from '../model/SendableObject';

const WATCH_SIZE: string = '466px';
const ITEM_WIDTH: string = '414px';
const ITEM_HEIGHT: string = '80px';
const LIST_SPACE_PX: number = 8;
const DIAGRAM_SIZE: number = 200;
const CENTER: number = 100;
const ORBIT_R: number = 58;
const NODE_R: number = 22;
const GLOW_R: number = 30;
const ARROW_OFFSET: number = 26;

interface StateNode {
  label: string;
  angleDeg: number;
  trigger: string;
}

const STATE_NODES: StateNode[] = [
  { label: 'Created',    angleDeg: 270, trigger: 'onCreate'     },
  { label: 'Foreground', angleDeg: 0,   trigger: 'onForeground' },
  { label: 'Background', angleDeg: 90,  trigger: 'onBackground' },
  { label: 'Destroyed',  angleDeg: 180, trigger: 'onDestroy'    }
];

function degToRad(deg: number): number { return deg * Math.PI / 180; }
function nodeX(a: number): number { return CENTER + ORBIT_R * Math.cos(degToRad(a)); }
function nodeY(a: number): number { return CENTER + ORBIT_R * Math.sin(degToRad(a)); }

function appStorageWrite<T>(key: string, value: T): void {
  AppStorage.delete(key);
  AppStorage.setOrCreate<T>(key, value);
}

@Entry
@Component
struct Index {

  @StorageLink(Constants.KEY_MODULE_NAME)  moduleName: string = Constants.PLACEHOLDER_PENDING;
  @StorageLink(Constants.KEY_STAGE_MODE)   stageMode: string = Constants.PLACEHOLDER_PENDING;

  @State workerPath: string = Constants.PLACEHOLDER_PENDING;
  @State lifecycleLog: string[] = [];
  @State activeNodeIndex: number = 0;
  @State glowOpacity: number = 1.0;
  @State glowScale: number = 1.0;
  @State isSending: boolean = false;

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private glowTimer: number = -1;
  private lastLogLength: number = 0;

  aboutToAppear(): void {
    const path = AppStorage.get<string>(Constants.KEY_WORKER_PATH);
    if (path !== undefined) { this.workerPath = path; }

    const log = AppStorage.get<string[]>(Constants.KEY_LIFECYCLE_LOG);
    if (log !== undefined && log.length > 0) {
      this.lastLogLength = log.length;
      this.lifecycleLog = [...log];
      this.updateActiveNode(log);
    }

    this.startPollTimer();
  }

  aboutToDisappear(): void {
    if (this.glowTimer >= 0) {
      clearInterval(this.glowTimer);
      this.glowTimer = -1;
    }
  }

  private startPollTimer(): void {
    this.glowTimer = setInterval(() => {
      const path = AppStorage.get<string>(Constants.KEY_WORKER_PATH);
      if (path !== undefined && path !== this.workerPath) {
        this.workerPath = path;
      }

      const log = AppStorage.get<string[]>(Constants.KEY_LIFECYCLE_LOG);
      if (log !== undefined && log.length !== this.lastLogLength) {
        this.lastLogLength = log.length;
        this.lifecycleLog = [...log];
        this.updateActiveNode(log);
      }
    }, 500);

    this.getUIContext().keyframeAnimateTo({ iterations: -1 }, [
      {
        duration: 600,
        event: () => {
          this.glowScale = 1.4;
          this.glowOpacity = 0.1;
        }
      },
      {
        duration: 600,
        event: () => {
          this.glowScale = 1.0;
          this.glowOpacity = 0.85;
        }
      }
    ]);
  }

  private updateActiveNode(log: string[]): void {
    if (log.length === 0) { return; }
    const last: string = log[log.length - 1];
    const idx: number = STATE_NODES.findIndex((n: StateNode) => n.trigger === last);
    if (idx >= 0 && idx !== this.activeNodeIndex) {
      this.activeNodeIndex = idx;
      this.glowScale = 1.0;
      this.glowOpacity = 1.0;
      this.drawDiagram();
    }
  }

  private drawDiagram(): void {
    const ctx: CanvasRenderingContext2D = this.canvasContext;
    ctx.clearRect(0, 0, DIAGRAM_SIZE, DIAGRAM_SIZE);
    ctx.beginPath();
    ctx.arc(CENTER, CENTER, ORBIT_R, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 1;
    ctx.stroke();
    for (let i = 0; i < STATE_NODES.length; i++) {
      this.drawArrow(ctx, STATE_NODES[i], STATE_NODES[(i + 1) % STATE_NODES.length]);
    }
    for (let i = 0; i < STATE_NODES.length; i++) {
      const node: StateNode = STATE_NODES[i];
      const x: number = nodeX(node.angleDeg);
      const y: number = nodeY(node.angleDeg);
      const active: boolean = i === this.activeNodeIndex;
      ctx.beginPath();
      ctx.arc(x, y, NODE_R, 0, Math.PI * 2);
      ctx.fillStyle = active ? 'rgba(79,195,247,0.25)' : 'rgba(255,255,255,0.05)';
      ctx.fill();
      ctx.beginPath();
      ctx.arc(x, y, NODE_R, 0, Math.PI * 2);
      ctx.strokeStyle = active ? '#FF4FC3F7' : 'rgba(255,255,255,0.3)';
      ctx.lineWidth = active ? 2 : 1;
      ctx.stroke();
    }
  }

  private drawArrow(ctx: CanvasRenderingContext2D, from: StateNode, to: StateNode): void {
    const x1 = nodeX(from.angleDeg), y1 = nodeY(from.angleDeg);
    const x2 = nodeX(to.angleDeg),   y2 = nodeY(to.angleDeg);
    const dx = x2 - x1, dy = y2 - y1;
    const len = Math.sqrt(dx * dx + dy * dy);
    const ux = dx / len, uy = dy / len;
    const sx = x1 + ux * ARROW_OFFSET, sy = y1 + uy * ARROW_OFFSET;
    const ex = x2 - ux * ARROW_OFFSET, ey = y2 - uy * ARROW_OFFSET;
    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(ex, ey);
    ctx.strokeStyle = 'rgba(255,255,255,0.25)'; ctx.lineWidth = 1; ctx.stroke();
    const h = 6, a = Math.atan2(ey - sy, ex - sx);
    ctx.beginPath(); ctx.moveTo(ex, ey);
    ctx.lineTo(ex - h * Math.cos(a - Math.PI / 6), ey - h * Math.sin(a - Math.PI / 6));
    ctx.moveTo(ex, ey);
    ctx.lineTo(ex - h * Math.cos(a + Math.PI / 6), ey - h * Math.sin(a + Math.PI / 6));
    ctx.strokeStyle = 'rgba(255,255,255,0.4)'; ctx.lineWidth = 1.5; ctx.stroke();
  }

  @Builder
  LifecycleDiagram() {
    Stack() {
      Canvas(this.canvasContext)
        .width(DIAGRAM_SIZE).height(DIAGRAM_SIZE)
        .onReady(() => { this.drawDiagram(); })

      ForEach(STATE_NODES, (node: StateNode) => {
        if (STATE_NODES.indexOf(node) === this.activeNodeIndex) {
          Circle()
            .width(GLOW_R * 2).height(GLOW_R * 2)
            .fill('rgba(79,195,247,0)').stroke('#FF4FC3F7').strokeWidth(3)
            .opacity(this.glowOpacity)
            .scale({ x: this.glowScale, y: this.glowScale })
            .position({ x: nodeX(node.angleDeg) - GLOW_R, y: nodeY(node.angleDeg) - GLOW_R })
        }
      }, (node: StateNode) => node.trigger)

      ForEach(STATE_NODES, (node: StateNode) => {
        Text(node.label)
          .fontSize(7)
          .fontColor(STATE_NODES.indexOf(node) === this.activeNodeIndex ? '#FF4FC3F7' : '#88FFFFFF')
          .fontWeight(STATE_NODES.indexOf(node) === this.activeNodeIndex ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.None })
          .width(NODE_R * 2)
          .position({ x: nodeX(node.angleDeg) - NODE_R, y: nodeY(node.angleDeg) - 5 })
      }, (node: StateNode) => `label_${node.trigger}`)
    }
    .width(DIAGRAM_SIZE).height(DIAGRAM_SIZE)
  }

  @Builder
  InfoRow(label: Resource, value: string) {
    Row() {
      Text(label)
        .fontSize($r('app.float.label_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
        .flexShrink(0).margin({ right: $r('app.float.padding_xs') })
      Text(value)
        .fontSize($r('app.float.info_font_size'))
        .fontColor($r('app.color.text_primary'))
        .flexGrow(1).textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
    }
    .width(ITEM_WIDTH).height(ITEM_HEIGHT)
    .padding({ left: $r('app.float.padding_md'), right: $r('app.float.padding_md') })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    Stack() {
      Column()
        .width(WATCH_SIZE).height(WATCH_SIZE)
        .clipShape(new CircleShape({ width: '100%', height: '100%' }))
        .backgroundColor($r('app.color.bg_primary'))

      ArcList({ initialIndex: 0 }) {

        ArcListItem() {
          Column() {
            Text($r('app.string.app_title'))
              .fontSize($r('app.float.title_font_size')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).textAlign(TextAlign.Center)
              .margin({ top: 16, bottom: 4 })
            this.LifecycleDiagram()
          }
          .width(ITEM_WIDTH).alignItems(HorizontalAlign.Center)
          .padding({ top: 0, bottom: 8 })
        }
        .autoScale(false)

        ArcListItem() { this.InfoRow($r('app.string.label_module'), this.moduleName) }
        ArcListItem() { this.InfoRow($r('app.string.label_stage_mode'), this.stageMode) }
        ArcListItem() { this.InfoRow($r('app.string.label_worker_path'), this.workerPath) }
        ArcListItem() {
          Button($r('app.string.btn_switch_area'))
            .type(ButtonType.Capsule).width(ITEM_WIDTH).height(ITEM_HEIGHT)
            .fontSize($r('app.float.label_font_size'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.btn_primary'))
            .onClick(() => {
              const abilityCtx = this.getUIContext().getHostContext() as common.UIAbilityContext;
              const currentIsEL1: boolean =
                abilityCtx.area === contextConstant.AreaMode.EL1;
              if (currentIsEL1) {
                abilityCtx.area = contextConstant.AreaMode.EL2;
                const log = AppStorage.get<string[]>(Constants.KEY_LIFECYCLE_LOG) ?? [];
                AppStorage.delete(Constants.KEY_LIFECYCLE_LOG);
                AppStorage.setOrCreate<string[]>(Constants.KEY_LIFECYCLE_LOG,
                  [...log, 'area:EL2']);
              } else {
                abilityCtx.area = contextConstant.AreaMode.EL1;
                const log = AppStorage.get<string[]>(Constants.KEY_LIFECYCLE_LOG) ?? [];
                AppStorage.delete(Constants.KEY_LIFECYCLE_LOG);
                AppStorage.setOrCreate<string[]>(Constants.KEY_LIFECYCLE_LOG,
                  [...log, 'area:EL1']);
              }
              hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG,
                'Area toggled, currentIsEL1 was: %{public}s', String(currentIsEL1));
            })
        }
        .autoScale(false)

        ArcListItem() {
          Button(this.isSending
            ? $r('app.string.btn_sending')
            : $r('app.string.btn_send_worker'))
            .type(ButtonType.Capsule).width(ITEM_WIDTH).height(ITEM_HEIGHT)
            .fontSize($r('app.float.label_font_size'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.btn_secondary'))
            .enabled(!this.isSending)
            .onClick(() => {
              if (this.isSending) { return; }
              this.isSending = true;
              this.workerPath = Constants.PLACEHOLDER_PENDING;

              try {
                const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
                const workerInstance = new worker.ThreadWorker(Constants.WORKER_ENTRY);

                workerInstance.onmessage = (e: MessageEvents): void => {
                  const msg: string = e.data as string;
                  if (msg.startsWith(Constants.WORKER_MSG_PREFIX)) {
                    const path: string = msg.substring(Constants.WORKER_MSG_PREFIX.length);
                    this.workerPath = path;
                    appStorageWrite<string>(Constants.KEY_WORKER_PATH, path);
                  }
                  this.isSending = false;
                  workerInstance.terminate();
                };

                workerInstance.onerror = (): void => {
                  this.workerPath = Constants.PLACEHOLDER_UNKNOWN;
                  this.isSending = false;
                  workerInstance.terminate();
                };

                const sendableCtx: sendableContextManager.SendableContext =
                  sendableContextManager.convertFromContext(ctx as common.Context);
                workerInstance.postMessageWithSharedSendable(
                  new SendableObject(sendableCtx, Constants.CONTEXT_TAG_BASE)
                );
              } catch (err) {
                hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG,
                  'sendContextToWorker failed: %{public}s', JSON.stringify(err));
                this.workerPath = Constants.PLACEHOLDER_UNKNOWN;
                this.isSending = false;
              }
            })
        }
        .autoScale(false)

        ArcListItem() {
          Text($r('app.string.label_lifecycle_log'))
            .fontSize($r('app.float.label_font_size')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_accent')).textAlign(TextAlign.Center)
            .width(ITEM_WIDTH)
        }
        .autoScale(false)

        ForEach(this.lifecycleLog, (event: string) => {
          ArcListItem() {
            Text(`\u2713 ${event}`)
              .fontSize($r('app.float.info_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center).width(ITEM_WIDTH)
          }
        }, (event: string) => event)

      }
      .space(LengthMetrics.px(LIST_SPACE_PX))
      .borderRadius(WATCH_SIZE)
      .focusable(true).focusOnTouch(true).defaultFocus(true)
      .width(WATCH_SIZE).height(WATCH_SIZE)
    }
    .width(WATCH_SIZE).height(WATCH_SIZE).alignContent(Alignment.Center)
  }
}
