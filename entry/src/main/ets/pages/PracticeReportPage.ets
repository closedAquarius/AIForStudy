import { router } from '@kit.ArkUI';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import {
  PracticeAnswerResultItem,
  PracticeKnowledgeAnalysisItem,
  PracticeReportData,
  getPracticeReport
} from '../common/ApiClient';

interface PracticeReportParams {
  sessionId?: string;
}

@Entry
@Component
struct PracticeReportPage {
  @State sessionId: number = 0;
  @State loading: boolean = false;
  @State message: string = '';
  @State report: PracticeReportData | null = null;
  @State showWrongOnly: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as PracticeReportParams;
    this.sessionId = Number(params?.sessionId ?? '0');
    this.loadReport();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadReport(): Promise<void> {
    if (this.sessionId <= 0) {
      this.message = '成绩报告参数错误';
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const result = await getPracticeReport(this.getToken(), this.sessionId);
      if (result.success && result.data) {
        this.report = result.data;
      } else {
        this.message = result.message || '成绩报告加载失败';
      }
    } catch (error) {
      this.message = `成绩报告加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private formatDuration(seconds: number): string {
    const minutes = Math.floor(Math.max(0, seconds) / 60);
    const remain = Math.max(0, seconds) % 60;
    return `${minutes}分${remain}秒`;
  }

  private scoreLevel(): string {
    if (!this.report) {
      return '';
    }
    if (this.report.scoreRate >= 90) {
      return '优秀';
    }
    if (this.report.scoreRate >= 75) {
      return '良好';
    }
    if (this.report.scoreRate >= 60) {
      return '及格';
    }
    return '需要加强';
  }

  private visibleAnswers(): PracticeAnswerResultItem[] {
    if (!this.report) {
      return [];
    }
    if (!this.showWrongOnly) {
      return this.report.answers;
    }
    return this.report.answers.filter((item: PracticeAnswerResultItem) => item.isCorrect !== 1);
  }

  private percentWidth(value: number): string {
    return `${Math.max(4, Math.min(100, value))}%`;
  }

  @Builder
  StatItem(value: string, label: string, color: string) {
    Column({ space: 5 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .height(78)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#E5EAF3' })
    .borderRadius(8)
  }

  @Builder
  KnowledgeRow(item: PracticeKnowledgeAnalysisItem) {
    Column({ space: 7 }) {
      Row() {
        Text(item.knowledgePoint)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0B1B44')
          .layoutWeight(1)
          .maxLines(1)
        Text(`${item.correctCount}/${item.totalCount} · ${item.accuracyRate}%`)
          .fontSize(12)
          .fontColor(item.accuracyRate < 60 ? '#EF4444' : '#16A66A')
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor('#EEF2F7')
        Column()
          .width(this.percentWidth(item.accuracyRate))
          .height(8)
          .borderRadius(4)
          .backgroundColor(item.accuracyRate < 60 ? '#EF4444' : '#2D75FF')
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
  }

  @Builder
  AnswerCard(item: PracticeAnswerResultItem) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(`#${item.seq ?? 0}`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D75FF')
        Text(item.typeLabel ?? '题目')
          .fontSize(12)
          .fontColor('#64748B')
        Blank()
        Text(item.isCorrect === 1 ? `+${item.earnedScore} 分` : `0/${item.score} 分`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.isCorrect === 1 ? '#16A66A' : '#EF4444')
      }
      .width('100%')

      Text(item.stem ?? '')
        .width('100%')
        .fontSize(15)
        .fontColor('#0B1B44')
        .lineHeight(22)

      Text(`你的答案：${item.userAnswer.length > 0 ? item.userAnswer : '未作答'}`)
        .width('100%')
        .fontSize(13)
        .fontColor(item.isCorrect === 1 ? '#16794D' : '#B42318')
        .padding(10)
        .backgroundColor(item.isCorrect === 1 ? '#ECFDF5' : '#FFF1F2')
        .borderRadius(6)

      if (item.isCorrect !== 1) {
        Text(`正确答案：${item.correctAnswer.length > 0 ? item.correctAnswer : '请参考解析'}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#2563EB')

        Text(`解析：${item.analysis.length > 0 ? item.analysis : '暂无解析'}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#475569')
          .lineHeight(20)
      }

      if (item.knowledgePoint.length > 0) {
        Text(item.knowledgePoint)
          .fontSize(11)
          .fontColor('#64748B')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#F1F5F9')
          .borderRadius(6)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: item.isCorrect === 1 ? '#E5EAF3' : '#FECACA' })
    .borderRadius(8)
  }

  build() {
    Column() {
      FeaturePageHeader({
        title: '成绩报告',
        themeColor: '#2D75FF'
      })

      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress().width(42).height(42)
          Text('正在生成成绩报告...').fontSize(14).fontColor('#64748B')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.report) {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 8 }) {
              Text(this.report.bankName)
                .width('100%')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0B1B44')
                .textAlign(TextAlign.Center)
              Text(`${this.report.earnedScore} / ${this.report.totalScore}`)
                .fontSize(42)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2D75FF')
              Text(`${this.scoreLevel()} · 得分率 ${this.report.scoreRate}%`)
                .fontSize(14)
                .fontColor('#64748B')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)

            Row({ space: 8 }) {
              this.StatItem(`${this.report.correctCount}/${this.report.totalCount}`, '答对题目', '#16A66A')
              this.StatItem(`${this.report.accuracyRate}%`, '正确率', '#2D75FF')
              this.StatItem(this.formatDuration(this.report.durationSeconds), '考试用时', '#F59E0B')
            }
            .width('100%')

            Column({ space: 2 }) {
              Text('知识点分析')
                .width('100%')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0B1B44')
                .margin({ bottom: 6 })
              ForEach(this.report.knowledgeAnalysis, (item: PracticeKnowledgeAnalysisItem) => {
                this.KnowledgeRow(item)
              }, (item: PracticeKnowledgeAnalysisItem) => item.knowledgePoint)
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)

            Row() {
              Text('答题详情')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0B1B44')
              Blank()
              Button(this.showWrongOnly ? '查看全部' : '只看错题')
                .height(34)
                .fontSize(12)
                .fontColor('#2D75FF')
                .backgroundColor('#EEF5FF')
                .borderRadius(6)
                .onClick(() => {
                  this.showWrongOnly = !this.showWrongOnly;
                })
            }
            .width('100%')

            ForEach(this.visibleAnswers(), (item: PracticeAnswerResultItem) => {
              this.AnswerCard(item)
            }, (item: PracticeAnswerResultItem) => item.questionId.toString())

            if (this.visibleAnswers().length === 0) {
              Text('本次没有错题，表现很稳。')
                .width('100%')
                .height(80)
                .fontSize(14)
                .fontColor('#16A66A')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 28 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        Text(this.message.length > 0 ? this.message : '暂无成绩报告')
          .width('100%')
          .layoutWeight(1)
          .fontSize(14)
          .fontColor('#EF4444')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FC')
  }
}
