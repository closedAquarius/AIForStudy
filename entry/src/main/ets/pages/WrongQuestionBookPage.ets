import { router } from '@kit.ArkUI';
import {
  AiWrongQuestionItem,
  explainWrongQuestion,
  getWrongQuestions,
  removeWrongQuestion
} from '../common/ApiClient';
import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct WrongQuestionBookPage {
  @State loading: boolean = false;
  @State questions: AiWrongQuestionItem[] = [];
  @State keyword: string = '';
  @State expandedIds: number[] = [];
  @State explainingId: number = 0;
  @State removingId: number = 0;
  @State explanationQuestionId: number = 0;
  @State explanationText: string = '';
  @State message: string = '';

  aboutToAppear(): void {
    this.loadQuestions();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadQuestions(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const result = await getWrongQuestions(this.getToken(), 0, 100);
      if (result.success && result.data) {
        this.questions = result.data.questions;
        if (this.questions.length === 0) {
          this.message = '当前没有待复习错题，继续保持。';
        }
      } else {
        this.message = result.message || '错题加载失败';
      }
    } catch (error) {
      this.message = `错题加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private filteredQuestions(): AiWrongQuestionItem[] {
    const keyword = this.keyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.questions;
    }
    const result: AiWrongQuestionItem[] = [];
    this.questions.forEach((item: AiWrongQuestionItem) => {
      const content = `${item.stem} ${item.bankName} ${item.knowledgePoint} ${item.tags.join(' ')}`.toLowerCase();
      if (content.indexOf(keyword) >= 0) {
        result.push(item);
      }
    });
    return result;
  }

  private isExpanded(questionId: number): boolean {
    return this.expandedIds.indexOf(questionId) >= 0;
  }

  private toggleExpanded(questionId: number): void {
    const next: number[] = [];
    let exists = false;
    this.expandedIds.forEach((id: number) => {
      if (id === questionId) {
        exists = true;
      } else {
        next.push(id);
      }
    });
    if (!exists) {
      next.push(questionId);
    }
    this.expandedIds = next;
  }

  private typeText(type: string): string {
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
    return type.length > 0 ? type : '题目';
  }

  private async explainQuestion(question: AiWrongQuestionItem): Promise<void> {
    if (this.explainingId > 0) {
      return;
    }
    this.explainingId = question.id;
    this.explanationQuestionId = question.id;
    this.explanationText = 'AI 正在分析这道错题...';
    try {
      const result = await explainWrongQuestion(this.getToken(), question.id);
      if (result.success && result.data) {
        this.explanationText = result.data.explanation;
      } else {
        this.explanationText = result.message || 'AI 讲解生成失败';
      }
    } catch (error) {
      this.explanationText = `AI 讲解生成失败：${(error as Error).message}`;
    } finally {
      this.explainingId = 0;
    }
  }

  private async removeQuestion(question: AiWrongQuestionItem): Promise<void> {
    if (this.removingId > 0) {
      return;
    }
    this.removingId = question.id;
    this.message = '';
    try {
      const result = await removeWrongQuestion(this.getToken(), question.id);
      if (result.success) {
        this.questions = this.questions.filter(
          (item: AiWrongQuestionItem) => item.id !== question.id
        );
        this.expandedIds = this.expandedIds.filter((id: number) => id !== question.id);
        if (this.explanationQuestionId === question.id) {
          this.explanationQuestionId = 0;
          this.explanationText = '';
        }
        this.message = '已移出错题本';
      } else {
        this.message = result.message || '移出失败';
      }
    } catch (error) {
      this.message = `移出失败：${(error as Error).message}`;
    } finally {
      this.removingId = 0;
    }
  }

  @Builder
  Tag(text: string, color: string) {
    Text(text)
      .fontSize(10)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('#F5F7FB')
      .borderRadius(6)
  }

  @Builder
  QuestionCard(question: AiWrongQuestionItem) {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        this.Tag(this.typeText(question.type), '#2D75FF')
        this.Tag(`难度 ${question.difficulty}`, '#F59E0B')

        Blank()

        Text(question.latestAnsweredAt.length > 0 ? question.latestAnsweredAt.substring(0, 10) : '')
          .fontSize(10)
          .fontColor('#94A3B8')
      }
      .width('100%')

      Text(question.stem)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .lineHeight(23)
        .fontColor('#0B1B44')

      Row() {
        Column({ space: 3 }) {
          Text(question.bankName)
            .fontSize(11)
            .fontColor('#64748B')
            .maxLines(1)

          if (question.knowledgePoint.length > 0) {
            Text(`知识点：${question.knowledgePoint}`)
              .fontSize(11)
              .fontColor('#64748B')
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.removingId === question.id ? '移出中...' : '移出')
          .height(32)
          .fontSize(12)
          .fontColor('#DC2626')
          .backgroundColor('#FFF1F2')
          .borderRadius(8)
          .enabled(this.removingId === 0)
          .onClick(() => {
            this.removeQuestion(question);
          })

        Button(this.isExpanded(question.id) ? '收起解析' : '查看解析')
          .height(32)
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#EEF5FF')
          .borderRadius(8)
          .onClick(() => {
            this.toggleExpanded(question.id);
          })
      }
      .width('100%')

      if (this.isExpanded(question.id)) {
        Column({ space: 8 }) {
          Text('题目解析')
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          Text(question.analysis.length > 0 ? question.analysis : '这道题暂时没有人工解析，可以使用 AI 讲解。')
            .width('100%')
            .fontSize(13)
            .lineHeight(21)
            .fontColor('#475569')

          Button(this.explainingId === question.id ? '讲解中...' : 'AI 讲解')
            .width('100%')
            .height(38)
            .fontSize(13)
            .fontColor('#7C3AED')
            .backgroundColor('#F3EEFF')
            .borderRadius(8)
            .enabled(this.explainingId === 0)
            .onClick(() => {
              this.explainQuestion(question);
            })

          if (this.explanationQuestionId === question.id && this.explanationText.length > 0) {
            Text(this.explanationText)
              .width('100%')
              .fontSize(13)
              .lineHeight(21)
              .fontColor('#334155')
              .padding(10)
              .backgroundColor('#FAF8FF')
              .borderRadius(8)
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8FAFD')
        .borderRadius(8)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#E5EAF3' })
  }

  build() {
    Column() {
      FeaturePageHeader({
        title: '我的错题本',
        themeColor: '#EF4444'
      })

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索题目、题库或知识点', text: this.keyword })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .backgroundColor('#F3F5F8')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.keyword = value;
          })

        Button('刷新')
          .width(64)
          .height(42)
          .fontSize(13)
          .fontColor('#2563EB')
          .backgroundColor('#EEF5FF')
          .borderRadius(8)
          .onClick(() => {
            this.loadQuestions();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')

      Row() {
        Text(`当前错题 ${this.questions.length} 道`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#EF4444')
          .layoutWeight(1)

        Text('答对后将自动移出错题本')
          .fontSize(11)
          .fontColor('#64748B')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#FFF7F7')

      if (this.loading) {
        Text('正在加载错题...')
          .width('100%')
          .fontSize(13)
          .fontColor('#64748B')
          .textAlign(TextAlign.Center)
          .padding({ top: 28 })
      } else if (this.filteredQuestions().length === 0) {
        Column({ space: 10 }) {
          Text(this.keyword.trim().length > 0 ? '没有匹配的错题' : '错题本是空的')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          Text(this.message.length > 0 ? this.message : '继续刷题，答错的题会自动收录到这里。')
            .fontSize(13)
            .fontColor('#64748B')
            .textAlign(TextAlign.Center)

          Button('去刷题')
            .width(120)
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/PracticePage'
              });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.filteredQuestions(), (question: AiWrongQuestionItem) => {
              this.QuestionCard(question)
            }, (question: AiWrongQuestionItem) => `${question.id}`)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5F7FB')
      }
    }
    .width('100%')
    .height('100%')
  }
}
