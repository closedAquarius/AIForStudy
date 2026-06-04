import { router } from '@kit.ArkUI';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import {
  ChartItem,
  QuestionBankDetail,
  RecentQuestion,
  getQuestionBankDetail
} from '../common/ApiClient';

@Entry
@Component
struct QuestionBankDetailPage {
  @State bankId: number = 0;
  @State loading: boolean = false;
  @State message: string = '';
  @State detail: QuestionBankDetail | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.bankId = Number(params['bankId'] ?? '0');
    }
    this.loadDetail();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadDetail(): Promise<void> {
    if (this.bankId <= 0) {
      this.message = '题库参数错误';
      return;
    }

    this.loading = true;
    this.message = '';

    try {
      const result = await getQuestionBankDetail(this.getToken(), this.bankId);
      if (result.success && result.data) {
        this.detail = result.data;
      } else {
        this.message = result.message || '题库详情加载失败';
      }
    } catch (error) {
      this.message = `题库详情加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private percentWidth(value: number): string {
    if (value <= 0) {
      return '0%';
    }
    return `${Math.max(8, Math.min(100, value))}%`;
  }

  @Builder
  HeaderBar() {
    Row() {
      Row({ space: 3 }) {
        Text('‹')
          .fontSize(30)
          .fontColor('#2D75FF')
          .margin({ bottom: 3 })

        Text('返回')
          .fontSize(16)
          .fontColor('#2D75FF')
      }
      .width(78)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(19)
      .backgroundColor('#EEF5FF')
      .onClick(() => {
        router.back();
      })

      Text('题库详情')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
        .maxLines(1)

      Row({ space: 6 }) {
        Button('查看题目')
          .height(34)
          .fontSize(12)
          .borderRadius(15)
          .backgroundColor('#EEF5FF')
          .fontColor('#2D75FF')
          .onClick(() => {
            router.pushUrl({
              url: 'pages/QuestionListPage',
              params: {
                bankId: this.bankId.toString()
              }
            });
          })

        Button('开始刷题')
          .height(34)
          .fontSize(12)
          .borderRadius(15)
          .backgroundColor('#2D75FF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.message = '开始刷题页面将在下一步开发';
          })
      }
      .width(150)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(86)
    .padding({ left: 18, right: 18, top: 32 })
    .backgroundColor('#FFFFFF')
    .border({
      width: { bottom: 1 },
      color: '#EEF2F7'
    })
  }

  @Builder
  StatCard(value: string, label: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(label)
        .fontSize(12)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .height(82)
    .justifyContent(FlexAlign.Center)
    .borderRadius(20)
    .backgroundColor('#FFFFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
  }

  @Builder
  BarRow(item: ChartItem, color: string) {
    Row({ space: 10 }) {
      Text(item.label)
        .width(72)
        .fontSize(13)
        .fontColor('#4B5563')
        .maxLines(1)

      Stack({ alignContent: Alignment.Start }) {
        Column()
          .height(10)
          .width('100%')
          .borderRadius(5)
          .backgroundColor('#EEF2F7')

        Column()
          .height(10)
          .width(this.percentWidth(item.ratio))
          .borderRadius(5)
          .backgroundColor(color)
      }
      .layoutWeight(1)

      Text(item.value.toString())
        .width(34)
        .fontSize(13)
        .fontColor('#0B1B44')
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(28)
  }

  @Builder
  ChartBlock(title: string, items: ChartItem[], color: string) {
    Column({ space: 10 }) {
      Text(title)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      if (items.length === 0) {
        Text('暂无数据')
          .width('100%')
          .height(52)
          .fontSize(14)
          .fontColor('#94A3B8')
          .textAlign(TextAlign.Center)
      } else {
        ForEach(items, (item: ChartItem) => {
          this.BarRow(item, color)
        }, (item: ChartItem) => item.label)
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor('#FFFFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
  }

  @Builder
  QuestionItem(question: RecentQuestion) {
    Column({ space: 8 }) {
      Row() {
        Text(question.typeLabel)
          .fontSize(12)
          .fontColor('#2D75FF')
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor('#EAF3FF')

        Text(`难度 ${question.difficulty}`)
          .fontSize(12)
          .fontColor('#64748B')
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')

      Text(question.stem)
        .width('100%')
        .fontSize(14)
        .fontColor('#0B1B44')
        .lineHeight(21)
        .maxLines(2)

      if (question.knowledgePoint.length > 0) {
        Text(`知识点：${question.knowledgePoint}`)
          .width('100%')
          .fontSize(12)
          .fontColor('#64748B')
          .maxLines(1)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor('#F8FBFF')
  }

  @Builder
  DetailContent() {
    if (this.detail) {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text(this.detail.bank.name)
            .fontSize(27)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')
            .width('100%')

          Text(this.detail.bank.description.length > 0 ? this.detail.bank.description : '暂无题库描述')
            .fontSize(14)
            .fontColor('#64748B')
            .lineHeight(22)
            .width('100%')

          Row({ space: 8 }) {
            Text(this.detail.bank.subjectName)
              .fontSize(12)
              .fontColor('#2D75FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(14)
              .backgroundColor('#EAF3FF')

            Text(this.detail.bank.canManage ? '我创建的题库' : '公开题库')
              .fontSize(12)
              .fontColor(this.detail.bank.canManage ? '#38C98A' : '#8A96AD')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(14)
              .backgroundColor('#F1F5F9')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .borderRadius(26)
        .backgroundColor('#EFFFFFFF')
        .border({ width: 1, color: '#FFFFFFFF' })

        Row({ space: 10 }) {
          this.StatCard(this.detail.stats.totalQuestions.toString(), '题目总数', '#2D75FF')
          this.StatCard(this.detail.stats.practicedQuestions.toString(), '已刷', '#38C98A')
          this.StatCard(this.detail.stats.wrongQuestions.toString(), '错题', '#EF4444')
        }
        .width('100%')

        Row({ space: 10 }) {
          this.StatCard(this.detail.stats.unpracticedQuestions.toString(), '未刷', '#8B67FF')
          this.StatCard(this.detail.stats.needsReviewQuestions.toString(), '待复习', '#FFAA45')
          this.StatCard(`${this.detail.stats.accuracyRate}%`, '正确率', '#0EA5E9')
        }
        .width('100%')

        this.ChartBlock('题型分布', this.detail.typeDistribution, '#2D75FF')
        this.ChartBlock('难度分布', this.detail.difficultyDistribution, '#38C98A')
        this.ChartBlock('标签分布', this.detail.tagDistribution, '#8B67FF')

        Column({ space: 10 }) {
          Text('最近题目')
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          if (this.detail.recentQuestions.length === 0) {
            Text('暂无题目')
              .width('100%')
              .height(54)
              .fontSize(14)
              .fontColor('#94A3B8')
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.detail.recentQuestions, (question: RecentQuestion) => {
              this.QuestionItem(question)
            }, (question: RecentQuestion) => question.id.toString())
          }
        }
        .width('100%')
        .padding(18)
        .borderRadius(24)
        .backgroundColor('#FFFFFFFF')
        .border({ width: 1, color: '#EEF2F7' })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }
  }

  build() {
    Column() {
      this.HeaderBar()

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor(this.message.includes('失败') || this.message.includes('错误') ? '#EF4444' : '#2D75FF')
          .width('100%')
          .padding({ left: 20, right: 20, top: 8 })
      }

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)

          Text('正在加载题库详情...')
            .fontSize(14)
            .fontColor('#64748B')
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          this.DetailContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      FeatureBottomNav({
        selectedIndex: 1
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FC')
  }
}