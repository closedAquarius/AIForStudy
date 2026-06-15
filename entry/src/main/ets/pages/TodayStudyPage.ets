import { router } from '@kit.ArkUI';
import {
  DailyReviewTaskItem,
  TodayReviewPlanData,
  getTodayReviewPlan,
  startTodayReviewPlan,
  regenerateTodayReviewPlan,
  updateTodayReviewTask
} from '../common/ApiClient';
import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct TodayStudyPage {
  @State loading: boolean = false;
  @State starting: boolean = false;
  @State message: string = '';
  @State plan: TodayReviewPlanData | null = null;
  @State updatingTaskId: number = 0;
  @State regenerating: boolean = false;

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
    return Math.max(0, Math.min(100, this.plan.handledCount * 100 / this.plan.totalCount));
  }

  private sourceLabel(sourceType: string): string {
    if (sourceType === 'wrong_question') {
      return '到期错题';
    }
    if (sourceType === 'favorite') {
      return '我的收藏';
    }
    return '薄弱知识点';
  }

  private sourceColor(sourceType: string): string {
    if (sourceType === 'wrong_question') {
      return '#DC2626';
    }
    if (sourceType === 'favorite') {
      return '#B45309';
    }
    return '#7C3AED';
  }

  private sourceBackground(sourceType: string): string {
    if (sourceType === 'wrong_question') {
      return '#FFF1F2';
    }
    if (sourceType === 'favorite') {
      return '#FFF7E6';
    }
    return '#F3EEFF';
  }

  private statusLabel(item: DailyReviewTaskItem): string {
    if (item.status === 'completed') {
      return item.isCorrect === 1 ? '已掌握' : '需再复习';
    }
    if (item.status === 'skipped') {
      return '今日已跳过';
    }
    if (item.status === 'postponed') {
      return '已安排明天';
    }
    return '待完成';
  }

  private statusColor(item: DailyReviewTaskItem): string {
    if (item.status === 'completed') {
      return item.isCorrect === 1 ? '#16A66A' : '#EF4444';
    }
    if (item.status === 'pending') {
      return '#F59E0B';
    }
    return '#64748B';
  }

  private async updateTask(item: DailyReviewTaskItem, action: string): Promise<void> {
    if (this.updatingTaskId > 0 || !this.plan || this.plan.status === 'in_progress') {
      return;
    }
    this.updatingTaskId = item.id;
    this.message = '';
    try {
      const result = await updateTodayReviewTask(this.getToken(), item.id, action);
      if (result.success && result.data) {
        this.plan = result.data;
      } else {
        this.message = result.message || '任务调整失败';
      }
    } catch (error) {
      this.message = `任务调整失败：${(error as Error).message}`;
    } finally {
      this.updatingTaskId = 0;
    }
  }

  private async regeneratePlan(): Promise<void> {
    if (this.regenerating || !this.plan || this.plan.status === 'in_progress') {
      return;
    }
    this.regenerating = true;
    this.message = '';
    try {
      const result = await regenerateTodayReviewPlan(this.getToken());
      if (result.success && result.data) {
        this.plan = result.data;
      } else {
        this.message = result.message || '重新生成任务失败';
      }
    } catch (error) {
      this.message = `重新生成任务失败：${(error as Error).message}`;
    } finally {
      this.regenerating = false;
    }
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
          .fontColor(this.sourceColor(item.sourceType))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.sourceBackground(item.sourceType))
          .borderRadius(6)

        Text(this.typeLabel(item.type))
          .fontSize(10)
          .fontColor('#64748B')

        Blank()

        Text(this.statusLabel(item))
          .fontSize(11)
          .fontColor(this.statusColor(item))
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

      if (this.plan !== null && this.plan!.status !== 'in_progress' && item.status !== 'completed') {
        Row({ space: 8 }) {
          if (item.status === 'pending') {
            Button('明天再做')
              .layoutWeight(1)
              .height(34)
              .fontSize(12)
              .fontColor('#2563EB')
              .backgroundColor('#EEF5FF')
              .borderRadius(6)
              .enabled(this.updatingTaskId === 0)
              .onClick(() => {
                this.updateTask(item, 'postpone');
              })

            Button('跳过')
              .layoutWeight(1)
              .height(34)
              .fontSize(12)
              .fontColor('#64748B')
              .backgroundColor('#F1F5F9')
              .borderRadius(6)
              .enabled(this.updatingTaskId === 0)
              .onClick(() => {
                this.updateTask(item, 'skip');
              })
          } else {
            Button('恢复到今日任务')
              .width('100%')
              .height(34)
              .fontSize(12)
              .fontColor('#16A66A')
              .backgroundColor('#ECFDF5')
              .borderRadius(6)
              .enabled(this.updatingTaskId === 0)
              .onClick(() => {
                this.updateTask(item, 'restore');
              })
          }
        }
        .width('100%')
      }
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

                  Text(`${this.plan!.handledCount}/${this.plan!.totalCount} 项已处理 · ${this.plan!.completedCount} 题完成`)
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

              Row({ space: 8 }) {
                Text(`错题 ${this.plan!.sourceStats.wrongQuestion}`)
                  .fontSize(11)
                  .fontColor('#DC2626')
                Text(`薄弱点 ${this.plan!.sourceStats.weakKnowledge}`)
                  .fontSize(11)
                  .fontColor('#7C3AED')
                Text(`收藏 ${this.plan!.sourceStats.favorite}`)
                  .fontSize(11)
                  .fontColor('#B45309')
              }
              .width('100%')

              if (this.plan!.status !== 'in_progress') {
                Button(this.regenerating ? '生成中...' : '重新生成今日任务')
                  .width('100%')
                  .height(36)
                  .fontSize(12)
                  .fontColor('#16A66A')
                  .backgroundColor('#FFFFFF')
                  .borderRadius(6)
                  .enabled(!this.regenerating)
                  .onClick(() => {
                    this.regeneratePlan();
                  })
              }
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
              }, (item: DailyReviewTaskItem) => `${item.id}-${item.status}`)
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

        if (this.plan!.pendingCount > 0) {
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
