import { router } from '@kit.ArkUI';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import {
  KnowledgeGraphBankItem,
  KnowledgeGraphData,
  KnowledgeGraphNode,
  getKnowledgeGraph
} from '../common/ApiClient';

interface KnowledgeGraphParams {
  bankId?: string;
}

interface GraphPoint {
  x: number;
  y: number;
}

interface GraphVisualNode {
  key: string;
  title: string;
  subtitle: string;
  x: number;
  y: number;
  size: number;
  color: string;
  background: string;
  kind: string;
  bankId: number;
  node: KnowledgeGraphNode | null;
}

@Entry
@Component
struct KnowledgeGraphPage {
  @State bankId: number = 0;
  @State loading: boolean = false;
  @State message: string = '';
  @State data: KnowledgeGraphData | null = null;
  @State selectedNode: KnowledgeGraphNode | null = null;
  @State activeBankId: number = 0;
  @State panX: number = -320;
  @State panY: number = -310;
  @State scaleValue: number = 0.72;
  @State pulse: boolean = false;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private pulseTimer: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as KnowledgeGraphParams;
    this.bankId = Number(params?.bankId ?? '0');
    this.activeBankId = this.bankId;
    this.loadGraph();
    this.startPulse();
  }

  aboutToDisappear(): void {
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
    }
  }

  private startPulse(): void {
    this.pulseTimer = setInterval(() => {
      animateTo({ duration: 900, curve: Curve.EaseInOut }, () => {
        this.pulse = !this.pulse;
      });
    }, 1000);
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadGraph(): Promise<void> {
    this.loading = true;
    try {
      const result = await getKnowledgeGraph(this.getToken(), this.bankId);
      if (result.success && result.data) {
        this.data = result.data;
        if (this.bankId > 0) {
          this.activeBankId = this.bankId;
          this.focusExpandedGraph();
        } else {
          this.resetView();
        }
      } else {
        this.message = result.message || '知识图谱加载失败';
      }
    } catch (error) {
      this.message = `知识图谱加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private bankById(bankId: number): KnowledgeGraphBankItem | null {
    if (!this.data) return null;
    for (let i = 0; i < this.data.banks.length; i++) {
      if (this.data.banks[i].id === bankId) return this.data.banks[i];
    }
    return null;
  }

  private bankKnowledgeNodes(bankId: number): KnowledgeGraphNode[] {
    if (!this.data) return [];
    const nodes = this.data.nodes.filter((node: KnowledgeGraphNode) =>
      node.bankId === bankId && node.type === 'knowledge');
    nodes.sort((a: KnowledgeGraphNode, b: KnowledgeGraphNode) => {
      const rankA = a.level === 'weak' ? 4 : a.level === 'learning' ? 3 : a.level === 'mastered' ? 2 : 1;
      const rankB = b.level === 'weak' ? 4 : b.level === 'learning' ? 3 : b.level === 'mastered' ? 2 : 1;
      if (rankA !== rankB) return rankB - rankA;
      if (a.answerCount !== b.answerCount) return b.answerCount - a.answerCount;
      return b.questionCount - a.questionCount;
    });
    return nodes;
  }

  private levelLabel(level: string): string {
    if (level === 'mastered') return '已掌握';
    if (level === 'learning') return '学习中';
    if (level === 'weak') return '薄弱';
    return '未学习';
  }

  private levelColor(level: string): string {
    if (level === 'mastered') return '#19A66A';
    if (level === 'learning') return '#3478F6';
    if (level === 'weak') return '#E34D59';
    return '#8793A8';
  }

  private levelBackground(level: string): string {
    if (level === 'mastered') return '#E9FAF2';
    if (level === 'learning') return '#EAF2FF';
    if (level === 'weak') return '#FFF0F2';
    return '#F1F4F8';
  }

  private circlePoint(index: number, count: number, radius: number, centerX: number, centerY: number): GraphPoint {
    const angle = -Math.PI / 2 + Math.PI * 2 * index / Math.max(1, count);
    return {
      x: centerX + Math.cos(angle) * radius,
      y: centerY + Math.sin(angle) * radius
    };
  }

  private courseVisualNodes(): GraphVisualNode[] {
    if (!this.data) return [];
    const banks = this.data.banks.slice(0, 8);
    const result: GraphVisualNode[] = [];
    for (let i = 0; i < banks.length; i++) {
      const point = this.circlePoint(i, banks.length, banks.length <= 4 ? 230 : 310, 600, 600);
      const count = this.bankKnowledgeNodes(banks[i].id).length;
      result.push({
        key: `bank-${banks[i].id}`,
        title: banks[i].name,
        subtitle: `${count} 个知识点`,
        x: point.x,
        y: point.y,
        size: 116,
        color: '#FFFFFF',
        background: '#173469',
        kind: 'bank',
        bankId: banks[i].id,
        node: null
      });
    }
    return result;
  }

  private expandedVisualNodes(): GraphVisualNode[] {
    const bank = this.bankById(this.activeBankId);
    if (!bank) return [];
    const allNodes = this.bankKnowledgeNodes(this.activeBankId);
    const shown = allNodes.slice(0, 12);
    const result: GraphVisualNode[] = [{
      key: `bank-${bank.id}`,
      title: bank.name,
      subtitle: `${allNodes.length} 个知识点`,
      x: 600,
      y: 600,
      size: 132,
      color: '#FFFFFF',
      background: '#102A5C',
      kind: 'bank',
      bankId: bank.id,
      node: null
    }];
    for (let i = 0; i < shown.length; i++) {
      const ring = i < 6 ? 1 : 2;
      const ringItems = ring === 1 ? Math.min(6, shown.length) : shown.length - 6;
      const ringIndex = ring === 1 ? i : i - 6;
      const point = this.circlePoint(ringIndex, ringItems, ring === 1 ? 230 : 390, 600, 600);
      result.push({
        key: `node-${shown[i].id}`,
        title: shown[i].name,
        subtitle: `${this.levelLabel(shown[i].level)} ${shown[i].accuracyRate}%`,
        x: point.x,
        y: point.y,
        size: shown[i].level === 'weak' ? 104 : 92,
        color: this.levelColor(shown[i].level),
        background: this.levelBackground(shown[i].level),
        kind: 'knowledge',
        bankId: bank.id,
        node: shown[i]
      });
    }
    if (allNodes.length > shown.length) {
      result.push({
        key: 'more',
        title: `更多 ${allNodes.length - shown.length} 个`,
        subtitle: '已合并显示',
        x: 600,
        y: 1060,
        size: 88,
        color: '#65718E',
        background: '#EDF1F7',
        kind: 'more',
        bankId: bank.id,
        node: null
      });
    }
    return result;
  }

  private visualNodes(): GraphVisualNode[] {
    return this.activeBankId > 0 ? this.expandedVisualNodes() : this.courseVisualNodes();
  }

  private expandedRootNode(): GraphVisualNode {
    const nodes = this.expandedVisualNodes();
    return nodes.length > 0 ? nodes[0] : this.rootNode();
  }

  private rootNode(): GraphVisualNode {
    return {
      key: 'root',
      title: '我的学习',
      subtitle: this.data ? `${this.data.summary.totalCount} 个知识点` : '',
      x: 600,
      y: 600,
      size: 136,
      color: '#FFFFFF',
      background: '#102A5C',
      kind: 'root',
      bankId: 0,
      node: null
    };
  }

  private lineLength(a: GraphVisualNode, b: GraphVisualNode): number {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private lineAngle(a: GraphVisualNode, b: GraphVisualNode): number {
    return Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI;
  }

  private resetView(): void {
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.panX = -320;
      this.panY = -310;
      this.scaleValue = 0.72;
    });
  }

  private focusExpandedGraph(): void {
    animateTo({ duration: 360, curve: Curve.EaseOut }, () => {
      this.panX = -340;
      this.panY = -330;
      this.scaleValue = 0.68;
    });
  }

  private selectCourse(bankId: number): void {
    animateTo({ duration: 380, curve: Curve.EaseInOut }, () => {
      this.activeBankId = bankId;
      this.selectedNode = null;
    });
    this.focusExpandedGraph();
  }

  private zoom(delta: number): void {
    this.scaleValue = Math.max(0.45, Math.min(1.35, this.scaleValue + delta));
  }

  @Builder
  EdgeLine(a: GraphVisualNode, b: GraphVisualNode, strong: boolean) {
    Row()
      .width(this.lineLength(a, b))
      .height(strong ? 3 : 2)
      .backgroundColor(strong ? '#7FA8F8' : '#B9C9E6')
      .opacity(this.pulse ? 0.82 : 0.42)
      .position({ x: a.x, y: a.y })
      .rotate({ angle: this.lineAngle(a, b), centerX: 0, centerY: 0 })
  }

  @Builder
  VisualNode(node: GraphVisualNode) {
    Column({ space: 4 }) {
      Text(node.title)
        .width(node.size - 14)
        .fontSize(node.kind === 'bank' || node.kind === 'root' ? 15 : 12)
        .fontWeight(FontWeight.Bold)
        .fontColor(node.color)
        .textAlign(TextAlign.Center)
        .maxLines(2)
      Text(node.subtitle)
        .width(node.size - 12)
        .fontSize(9)
        .fontColor(node.kind === 'bank' || node.kind === 'root' ? '#D7E5FF' : node.color)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .width(node.size)
    .height(node.size)
    .justifyContent(FlexAlign.Center)
    .position({ x: node.x - node.size / 2, y: node.y - node.size / 2 })
    .backgroundColor(node.background)
    .borderRadius(node.size / 2)
    .border({ width: node.kind === 'knowledge' ? 2 : 0, color: node.color })
    .shadow({
      radius: node.kind === 'bank' || node.kind === 'root' ? 18 : 9,
      color: node.kind === 'bank' || node.kind === 'root' ? '#44102A5C' : '#22000000',
      offsetX: 0,
      offsetY: 5
    })
    .scale({
      x: this.pulse && (node.kind === 'bank' || node.kind === 'root') ? 1.035 : 1,
      y: this.pulse && (node.kind === 'bank' || node.kind === 'root') ? 1.035 : 1
    })
    .onClick(() => {
      if (node.kind === 'bank') {
        if (this.activeBankId === node.bankId) {
          this.activeBankId = 0;
          this.resetView();
        } else {
          this.selectCourse(node.bankId);
        }
      } else if (node.node) {
        this.selectedNode = node.node;
      }
    })
  }

  @Builder
  GraphSurface() {
    Stack() {
      if (this.activeBankId === 0) {
        ForEach(this.courseVisualNodes(), (node: GraphVisualNode) => {
          this.EdgeLine(this.rootNode(), node, true)
        }, (node: GraphVisualNode) => `edge-${node.key}`)
        this.VisualNode(this.rootNode())
      } else {
        ForEach(this.expandedVisualNodes().slice(1), (node: GraphVisualNode) => {
          this.EdgeLine(
            this.expandedRootNode(),
            node,
            node.kind === 'knowledge' && node.node !== null && node.node.level === 'weak'
          )
        }, (node: GraphVisualNode) => `edge-${node.key}`)
      }

      ForEach(this.visualNodes(), (node: GraphVisualNode) => {
        this.VisualNode(node)
      }, (node: GraphVisualNode) => node.key)
    }
    .width(1200)
    .height(1200)
    .translate({ x: this.panX, y: this.panY })
    .scale({ x: this.scaleValue, y: this.scaleValue, centerX: 600, centerY: 600 })
  }

  @Builder
  DetailPanel(node: KnowledgeGraphNode) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(node.name).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#0B1B44')
          Text(`${node.bankName} · ${this.levelLabel(node.level)}`)
            .fontSize(12).fontColor(this.levelColor(node.level))
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('关闭').height(32).fontSize(12).onClick(() => this.selectedNode = null)
      }
      Row({ space: 10 }) {
        Text(`${node.questionCount} 道相关题`).fontSize(13).fontColor('#2D75FF')
        Text(`${node.answerCount} 次作答`).fontSize(13).fontColor('#7C5CE7')
        Text(`正确率 ${node.accuracyRate}%`).fontSize(13).fontColor(this.levelColor(node.level))
      }
      Text(node.level === 'weak' ? '这是当前薄弱知识点，建议优先复习相关错题。' :
        node.level === 'unlearned' ? '尚未形成学习记录，可以先从基础题开始。' : '当前掌握较稳定，可以尝试提高题目难度。')
        .width('100%').fontSize(13).lineHeight(20).fontColor('#475569')
      Button('进入对应题库')
        .width('100%').height(42).fontColor('#FFFFFF').backgroundColor('#2D75FF').borderRadius(8)
        .onClick(() => router.pushUrl({
          url: 'pages/QuestionBankDetailPage',
          params: { bankId: node.bankId.toString() }
        }))
    }
    .width('90%').padding(18).backgroundColor('#FFFFFF').borderRadius(8)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        FeaturePageHeader({ title: '知识图谱', themeColor: '#2D75FF' })
        if (this.loading) {
          Column({ space: 10 }) {
            LoadingProgress().width(42).height(42)
            Text('正在组织知识关系...').fontSize(13).fontColor('#64748B')
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.data) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Column() {
              this.GraphSurface()
            }
            .width('100%')
            .height('100%')
            .clip(true)
            .gesture(
              PanGesture()
                .onActionStart(() => {
                  this.panStartX = this.panX;
                  this.panStartY = this.panY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.panX = this.panStartX + event.offsetX;
                  this.panY = this.panStartY + event.offsetY;
                })
            )

            Column({ space: 8 }) {
              Button('+').width(40).height(40).fontSize(20).onClick(() => this.zoom(0.12))
              Button('-').width(40).height(40).fontSize(20).onClick(() => this.zoom(-0.12))
              Button('复位').width(52).height(38).fontSize(11).onClick(() => {
                if (this.activeBankId > 0) this.focusExpandedGraph();
                else this.resetView();
              })
            }
            .margin({ top: 14, right: 14 })

            if (this.activeBankId > 0) {
              Button('返回课程总览')
                .height(38).fontSize(12).fontColor('#2D75FF')
                .backgroundColor('#EEF5FF').borderRadius(8)
                .position({ x: 14, y: 14 })
                .onClick(() => {
                  this.activeBankId = 0;
                  this.resetView();
                })
            }

            Text(this.activeBankId > 0 ? '拖动画布查看关系，点击知识点查看详情' : '点击课程展开知识点，拖动画布查看')
              .fontSize(11).fontColor('#64748B')
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor('#EFFFFFFF').borderRadius(8)
              .position({ x: 14, y: 62 })
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#F4F7FC')
        } else {
          Text(this.message.length > 0 ? this.message : '暂无知识点')
            .layoutWeight(1).fontSize(14).fontColor('#64748B')
        }
      }
      .width('100%').height('100%').backgroundColor('#F6F8FC')

      if (this.selectedNode) {
        Column() { this.DetailPanel(this.selectedNode!) }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center).backgroundColor('#77000000')
      }
    }
    .width('100%').height('100%')
  }
}
