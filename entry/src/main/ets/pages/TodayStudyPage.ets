import { router } from '@kit.ArkUI';
import {
  DailyReviewTaskItem,
  TodayReviewPlanData,
  getTodayReviewPlan,
  startTodayReviewPlan
} from '../common/ApiClient';
import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct TodayStudyPage {
  @State loading: boolean = false;
  @State starting: boolean = false;
  @State message: string = '';
  @State plan: TodayReviewPlanData | null = null;

  aboutToAppear(): void {
    this.loadPlan();
  }

  onPageShow(): void {
    this.loadPlan();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadPlan(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const result = await getTodayReviewPlan(this.getToken());
      if (result.success && result.data) {
        this.plan = result.data;
      } else {
        this.message = result.message || '今日学习计划加载失败';
      }
    } catch (error) {
      this.message = `今日学习计划加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private async startReview(): Promise<void> {
    if (this.starting || !this.plan || this.plan.totalCount === 0) {
      return;
    }
    this.starting = true;
    this.message = '';
    try {
      const result = await startTodayReviewPlan(this.getToken());
      if (result.success && result.data) {
        router.pushUrl({
          url: 'pages/PracticeExamPage',
          params: {
            sessionId: `${result.data.sessionId}`
          }
        });
      } else {
        this.message = result.message || '今日复习启动失败';
      }
    } catch (error) {
      this.message = `今日复习启动失败：${(error as Error).message}`;
    } finally {
      this.starting = false;
    }
  }

  private progressPercent(): number {
    if (!this.plan || this.plan.totalCount <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, this.plan.completedCount * 100 / this.plan.totalCount));
  }

  private sourceLabel(sourceType: string): string {
    return sourceType === 'wrong_question' ? '到期错题' : '薄弱知识点';
  }

  private typeLabel(type: string): string {
    if (type === 'single_choice') {
      return '单选题';
    }
    if (type === 'multiple_choice') {
      return '多选题';
    }
    if (type === 'true_false') {
      return '判断题';
    }
    if (type === 'short_answer') {
      return '简答题';
    }
    return '题目';
  }

  @Builder
  TaskCard(item: DailyReviewTaskItem) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.sourceLabel(item.sourceType))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.sourceType === 'wrong_question' ? '#DC2626' : '#7C3AED')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(item.sourceType === 'wrong_question' ? '#FFF1F2' : '#F3EEFF')
          .borderRadius(6)

        Text(this.typeLabel(item.type))
          .fontSize(10)
          .fontColor('#64748B')

        Blank()

        Text(item.status === 'completed' ? (item.isCorrect === 1 ? '已掌握' : '需再复习') : '待完成')
          .fontSize(11)
          .fontColor(item.status === 'completed' ? (item.isCorrect === 1 ? '#16A66A' : '#EF4444') : '#F59E0B')
      }
      .width('100%')

      Text(item.stem)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0B1B44')
        .lineHeight(21)
        .maxLines(3)

      Row() {
        Text(item.knowledgePoint.length > 0 ? item.knowledgePoint : item.bankName)
          .fontSize(11)
          .fontColor('#64748B')
          .layoutWeight(1)
          .maxLines(1)

        Text(`难度 ${item.difficulty}`)
          .fontSize(10)
          .fontColor('#94A3B8')
      }
      .width('100%')
    }
    .width('100%')
    .padding(13)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#E5EAF3' })
  }

  build() {
    Column() {
      FeaturePageHeader({
        title: '今日学习',
        themeColor: '#16A66A'
      })

      if (this.loading && this.plan === null) {
        Text('正在生成今日学习计划...')
          .width('100%')
          .layoutWeight(1)
          .fontSize(14)
          .fontColor('#64748B')
          .textAlign(TextAlign.Center)
      } else if (this.plan !== null) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Row() {
                Column({ space: 3 }) {
                  Text(this.plan!.status === 'completed' ? '今日任务已完成' : '今日复习任务')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0B1B44')

                  Text(`${this.plan!.completedCount}/${this.plan!.totalCount} 题`)
                    .fontSize(13)
                    .fontColor('#64748B')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column({ space: 2 }) {
                  Text(`${this.plan!.streakDays}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F59E0B')

                  Text('连续天数')
                    .fontSize(10)
                    .fontColor('#64748B')
                }
              }
              .width('100%')

              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(10)
                  .borderRadius(5)
                  .backgroundColor('#E8EEF3')

                Row()
                  .width(`${this.progressPercent()}%`)
                  .height(10)
                  .borderRadius(5)
                  .backgroundColor('#16A66A')
              }
              .width('100%')
              .height(10)

              Text(this.plan!.generationReason)
                .width('100%')
                .fontSize(12)
                .lineHeight(19)
                .fontColor('#475569')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F0FDF7')
            .borderRadius(8)
            .border({ width: 1, color: '#BFEBD5' })

            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text('AI')
                  .width(30)
                  .height(24)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#7C3AED')
                  .borderRadius(6)

                Text('日记状态调节')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0B1B44')
              }

              Text(this.plan!.moodSummary)
                .width('100%')
                .fontSize(12)
                .lineHeight(19)
                .fontColor('#475569')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FAF8FF')
            .borderRadius(8)
            .border({ width: 1, color: '#E4D9FF' })

            if (this.plan!.tasks.length === 0) {
              Column({ space: 8 }) {
                Text('今天没有到期任务')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0B1B44')

                Text('可以继续自由刷题，新的错题会自动进入间隔复习。')
                  .fontSize(13)
                  .fontColor('#64748B')
              }
              .width('100%')
              .height(150)
              .justifyContent(FlexAlign.Center)
            } else {
              Text('任务清单')
                .width('100%')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0B1B44')

              ForEach(this.plan!.tasks, (item: DailyReviewTaskItem) => {
                this.TaskCard(item)
              }, (item: DailyReviewTaskItem) => `${item.id}`)
            }

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(12)
                .fontColor('#DC2626')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 100 })
        }
        .layoutWeight(1)
        .width('100%')

        if (this.plan!.totalCount > 0) {
          Button(
            this.plan!.status === 'completed'
              ? '今日任务已完成'
              : (this.starting ? '正在准备...' : (this.plan!.status === 'in_progress' ? '继续今日学习' : '开始今日学习'))
          )
            .width('calc(100% - 32vp)')
            .height(48)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor(this.plan!.status === 'completed' ? '#94A3B8' : '#16A66A')
            .borderRadius(8)
            .margin({ left: 16, right: 16, bottom: 14 })
            .enabled(this.plan!.status !== 'completed' && !this.starting)
            .onClick(() => {
              this.startReview();
            })
        }
      } else {
        Text(this.message.length > 0 ? this.message : '今日学习计划暂不可用')
          .width('100%')
          .layoutWeight(1)
          .fontSize(14)
          .fontColor('#DC2626')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FB')
  }
}
