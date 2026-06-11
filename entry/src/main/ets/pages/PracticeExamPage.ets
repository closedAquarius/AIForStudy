import { router } from '@kit.ArkUI';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import {
  PracticeAnswerSubmitItem,
  PracticeQuestionItem,
  PracticeSessionData,
  QuestionOptionItem,
  getPracticeSession,
  submitPracticeSession
} from '../common/ApiClient';

interface PracticeExamParams {
  sessionId?: string;
}

interface LocalAnswer {
  questionId: number;
  value: string;
}

@Entry
@Component
struct PracticeExamPage {
  @State sessionId: number = 0;
  @State loading: boolean = false;
  @State submitting: boolean = false;
  @State message: string = '';
  @State session: PracticeSessionData | null = null;
  @State currentIndex: number = 0;
  @State currentQuestion: PracticeQuestionItem | null = null;
  @State answers: LocalAnswer[] = [];
  @State showAnswerCard: boolean = false;
  @State startedAtMillis: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as PracticeExamParams;
    if (params) {
      this.sessionId = Number(params.sessionId ?? '0');
    }
    this.startedAtMillis = Date.now();
    this.loadSession();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private showTip(message: string): void {
    AlertDialog.show({
      title: '提示',
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '知道了',
        action: () => {
        }
      }
    });
  }

  private syncCurrentQuestion(): void {
    if (!this.session || this.session.questions.length === 0) {
      this.currentQuestion = null;
      return;
    }

    if (this.currentIndex < 0) {
      this.currentIndex = 0;
    }

    if (this.currentIndex >= this.session.questions.length) {
      this.currentIndex = this.session.questions.length - 1;
    }

    this.currentQuestion = this.session.questions[this.currentIndex];
  }

  private currentQuestionList(): PracticeQuestionItem[] {
    const list: PracticeQuestionItem[] = [];
    if (this.currentQuestion !== null) {
      list.push(this.currentQuestion!);
    }
    return list;
  }

  private async loadSession(): Promise<void> {
    if (this.sessionId <= 0) {
      this.message = '刷题会话参数错误';
      return;
    }

    this.loading = true;
    this.message = '';
    try {
      const result = await getPracticeSession(this.getToken(), this.sessionId);
      if (result.success && result.data) {
        this.session = result.data;

        const nextAnswers: LocalAnswer[] = [];
        for (let i = 0; i < result.data.questions.length; i++) {
          nextAnswers.push({ questionId: result.data.questions[i].id, value: '' });
        }
        this.answers = nextAnswers;

        this.currentIndex = 0;
        this.syncCurrentQuestion();
      } else {
        this.message = result.message || '刷题会话加载失败';
      }
    } catch (error) {
      this.message = `刷题会话加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private questionIndexes(): number[] {
    const indexes: number[] = [];
    if (!this.session) {
      return indexes;
    }
    for (let i = 0; i < this.session.questions.length; i++) {
      indexes.push(i);
    }
    return indexes;
  }

  private answerValue(questionId: number): string {
    for (let i = 0; i < this.answers.length; i++) {
      if (this.answers[i].questionId === questionId) {
        return this.answers[i].value;
      }
    }
    return '';
  }

  private setAnswer(questionId: number, value: string): void {
    const next: LocalAnswer[] = [];
    let updated = false;
    for (let i = 0; i < this.answers.length; i++) {
      if (this.answers[i].questionId === questionId) {
        next.push({ questionId: questionId, value: value });
        updated = true;
      } else {
        next.push(this.answers[i]);
      }
    }
    if (!updated) {
      next.push({ questionId: questionId, value: value });
    }
    this.answers = next;
  }

  private splitMulti(value: string): string[] {
    if (value.trim().length === 0) {
      return [];
    }
    const parts = value.split(',');
    const result: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const item = parts[i].trim();
      if (item.length > 0) {
        result.push(item);
      }
    }
    return result;
  }

  private isSelected(question: PracticeQuestionItem, optionKey: string): boolean {
    const value = this.answerValue(question.id);
    if (question.type === 'multiple_choice') {
      return this.splitMulti(value).indexOf(optionKey) >= 0;
    }
    return value === optionKey;
  }

  private toggleOption(question: PracticeQuestionItem, optionKey: string): void {
    if (question.type === 'multiple_choice') {
      const selected = this.splitMulti(this.answerValue(question.id));
      const index = selected.indexOf(optionKey);
      if (index >= 0) {
        selected.splice(index, 1);
      } else {
        selected.push(optionKey);
      }
      selected.sort();
      this.setAnswer(question.id, selected.join(','));
      return;
    }

    this.setAnswer(question.id, optionKey);
  }

  private isAnsweredByQuestionId(questionId: number): boolean {
    return this.answerValue(questionId).trim().length > 0;
  }

  private answeredCount(): number {
    let count = 0;
    for (let i = 0; i < this.answers.length; i++) {
      if (this.answers[i].value.trim().length > 0) {
        count++;
      }
    }
    return count;
  }

  private statusText(question: PracticeQuestionItem): string {
    if (question.practiceStatus === 'unpracticed') {
      return '未刷';
    }
    if (question.practiceStatus === 'wrong') {
      return '错题';
    }
    return '已刷';
  }

  private statusColor(question: PracticeQuestionItem): string {
    if (question.practiceStatus === 'unpracticed') {
      return '#64748B';
    }
    if (question.practiceStatus === 'wrong') {
      return '#EF4444';
    }
    return '#2D75FF';
  }

  private starText(difficulty: number): string {
    if (difficulty <= 1) {
      return '⭐';
    }
    if (difficulty === 2) {
      return '⭐⭐';
    }
    if (difficulty === 3) {
      return '⭐⭐⭐';
    }
    if (difficulty === 4) {
      return '⭐⭐⭐⭐';
    }
    return '⭐⭐⭐⭐⭐';
  }

  private prevQuestion(): void {
    if (this.currentIndex > 0) {
      this.currentIndex -= 1;
      this.syncCurrentQuestion();
    }
  }

  private nextQuestion(): void {
    if (this.session && this.currentIndex < this.session.questions.length - 1) {
      this.currentIndex += 1;
      this.syncCurrentQuestion();
    }
  }

  private jumpToQuestion(index: number): void {
    if (!this.session || index < 0 || index >= this.session.questions.length) {
      return;
    }

    this.currentIndex = index;
    this.syncCurrentQuestion();
    this.showAnswerCard = false;
  }

  private elapsedSeconds(): number {
    return Math.max(0, Math.floor((Date.now() - this.startedAtMillis) / 1000));
  }

  private async submitAnswers(): Promise<void> {
    if (!this.session || this.submitting) {
      return;
    }

    this.submitting = true;
    const payload: PracticeAnswerSubmitItem[] = [];
    const usedSeconds = this.elapsedSeconds();
    for (let i = 0; i < this.answers.length; i++) {
      payload.push({
        question_id: this.answers[i].questionId,
        user_answer: this.answers[i].value,
        used_seconds: usedSeconds
      });
    }

    try {
      const result = await submitPracticeSession(this.getToken(), this.sessionId, payload);
      if (result.success && result.data) {
        this.showAnswerCard = false;
        AlertDialog.show({
          title: '提交成功',
          message: `本次共 ${result.data.totalCount} 题，答对 ${result.data.correctCount} 题，答错 ${result.data.wrongCount} 题，正确率 ${result.data.accuracyRate}%`,
          autoCancel: false,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: '返回题库',
            action: () => {
              router.back();
            }
          }
        });
      } else {
        this.message = result.message || '提交失败';
      }
    } catch (error) {
      this.message = `提交失败：${(error as Error).message}`;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  MetaChip(label: string, color: string, bgColor: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(color)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(bgColor)
  }

  @Builder
  OptionRow(question: PracticeQuestionItem, optionKey: string, content: string) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(30)
          .height(30)
          .fill(this.isSelected(question, optionKey) ? '#2D75FF' : '#EAF3FF')

        Text(optionKey)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isSelected(question, optionKey) ? '#FFFFFF' : '#2D75FF')
      }

      Text(content)
        .fontSize(15)
        .fontColor('#0B1B44')
        .lineHeight(22)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(13)
    .borderRadius(18)
    .backgroundColor(this.isSelected(question, optionKey) ? '#F0F6FF' : '#FFFFFF')
    .border({ width: 1, color: this.isSelected(question, optionKey) ? '#9EC5FF' : '#EEF2F7' })
    .onClick(() => {
      this.toggleOption(question, optionKey);
    })
  }

  @Builder
  TextAnswer(question: PracticeQuestionItem) {
    TextArea({ placeholder: '请输入你的答案', text: this.answerValue(question.id) })
      .width('100%')
      .height(130)
      .fontSize(15)
      .fontColor('#0B1B44')
      .placeholderColor('#94A3B8')
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .padding(14)
      .border({ width: 1, color: '#EEF2F7' })
      .onChange((value: string) => {
        this.setAnswer(question.id, value);
      })
  }

  @Builder
  QuestionCard(question: PracticeQuestionItem) {
    Column({ space: 16 }) {
      Row() {
        this.MetaChip(`#${question.seq}`, '#0B1B44', '#FFFFFF')
        Text(`${this.currentIndex + 1}/${this.session ? this.session.questions.length : 0}`)
          .fontSize(12)
          .fontColor('#64748B')
          .margin({ left: 8 })

        Blank()

        this.MetaChip(this.statusText(question), this.statusColor(question), '#FFFFFF')
      }
      .width('100%')

      Row({ space: 8 }) {
        this.MetaChip(question.typeLabel, '#2D75FF', '#EAF3FF')
        this.MetaChip(`难度 ${this.starText(question.difficulty)}`, '#64748B', '#F1F5F9')
      }
      .width('100%')

      Text(question.stem)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0B1B44')
        .lineHeight(28)

      if (question.knowledgePoint.length > 0) {
        Text(`知识点：${question.knowledgePoint}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#64748B')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(14)
          .backgroundColor('#F8FBFF')
      }

      if (question.options.length > 0) {
        Column({ space: 10 }) {
          ForEach(question.options, (option: QuestionOptionItem) => {
            this.OptionRow(question, option.optionKey, option.content)
          }, (option: QuestionOptionItem) => `${question.id}_${option.optionKey}`)
        }
        .width('100%')
      } else if (question.type === 'true_false') {
        Column({ space: 10 }) {
          this.OptionRow(question, 'true', '正确')
          this.OptionRow(question, 'false', '错误')
        }
        .width('100%')
      } else {
        this.TextAnswer(question)
      }
    }
    .width('100%')
    .padding(20)
    .borderRadius(26)
    .backgroundColor('#EFFFFFFF')
    .border({ width: 1, color: '#FFFFFFFF' })
    .shadow({
      radius: 14,
      color: '#146EA8FF',
      offsetX: 0,
      offsetY: 5
    })
  }

  @Builder
  AnswerDot(index: number) {
    if (this.session) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(40)
          .height(40)
          .fill(this.isAnsweredByQuestionId(this.session.questions[index].id) ? '#2D75FF' : '#E5EAF3')
          .stroke(this.currentIndex === index ? '#0B1B44' : '#00000000')
          .strokeWidth(this.currentIndex === index ? 2 : 0)

        Text((index + 1).toString())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isAnsweredByQuestionId(this.session.questions[index].id) ? '#FFFFFF' : '#64748B')
      }
      .width(46)
      .height(46)
      .onClick(() => {
        this.jumpToQuestion(index);
      })
    }
  }

  @Builder
  AnswerCardPanel() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 3 }) {
          Text('答题卡')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          Text(`已答 ${this.answeredCount()} / ${this.session ? this.session.questions.length : 0}`)
            .fontSize(13)
            .fontColor('#64748B')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('×')
          .width(32)
          .height(32)
          .fontSize(22)
          .fontColor('#64748B')
          .textAlign(TextAlign.Center)
          .borderRadius(16)
          .backgroundColor('#F1F5F9')
          .onClick(() => {
            this.showAnswerCard = false;
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.questionIndexes(), (index: number) => {
          this.AnswerDot(index)
        }, (index: number) => index.toString())
      }
      .width('100%')

      Row({ space: 12 }) {
        Row({ space: 6 }) {
          Circle().width(10).height(10).fill('#E5EAF3')
          Text('未答').fontSize(12).fontColor('#64748B')
        }
        Row({ space: 6 }) {
          Circle().width(10).height(10).fill('#2D75FF')
          Text('已答').fontSize(12).fontColor('#64748B')
        }
        Row({ space: 6 }) {
          Circle().width(10).height(10).fill('#FFFFFF').stroke('#0B1B44').strokeWidth(2)
          Text('当前').fontSize(12).fontColor('#64748B')
        }
        Blank()
      }
      .width('100%')

      Button(this.submitting ? '提交中...' : '提交答题卡')
        .width('100%')
        .height(48)
        .borderRadius(18)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor('#2D75FF')
        .enabled(!this.submitting)
        .onClick(() => {
          this.submitAnswers();
        })
    }
    .width('100%')
    .padding(22)
    .borderRadius({ topLeft: 28, topRight: 28 })
    .backgroundColor('#FFFFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: -6
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        FeaturePageHeader({
          title: this.session ? this.session.bankName : '刷题',
          themeColor: '#2D75FF'
        })

        if (this.message.length > 0) {
          Text(this.message)
            .width('100%')
            .fontSize(13)
            .fontColor(this.message.includes('失败') || this.message.includes('错误') ? '#EF4444' : '#2D75FF')
            .padding({ left: 20, right: 20, top: 8 })
        }

        if (this.loading) {
          Column() {
            LoadingProgress().width(42).height(42)
            Text('正在加载题目...')
              .fontSize(14)
              .fontColor('#64748B')
              .margin({ top: 10 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.session && this.session.questions.length > 0) {
          Scroll() {
            Column({ space: 18 }) {
              ForEach(this.currentQuestionList(), (question: PracticeQuestionItem) => {
                this.QuestionCard(question)
              }, (question: PracticeQuestionItem) => question.id.toString())

              Row({ space: 12 }) {
                Button('上一题')
                  .layoutWeight(1)
                  .height(46)
                  .borderRadius(18)
                  .fontColor(this.currentIndex > 0 ? '#2D75FF' : '#94A3B8')
                  .backgroundColor('#EAF3FF')
                  .enabled(this.currentIndex > 0)
                  .onClick(() => {
                    this.prevQuestion();
                  })

                Button('下一题')
                  .layoutWeight(1)
                  .height(46)
                  .borderRadius(18)
                  .fontColor(this.session && this.currentIndex < this.session.questions.length - 1 ? '#FFFFFF' : '#94A3B8')
                  .backgroundColor(this.session && this.currentIndex < this.session.questions.length - 1 ? '#2D75FF' : '#E5EAF3')
                  .enabled(this.session !== null && this.currentIndex < this.session.questions.length - 1)
                  .onClick(() => {
                    this.nextQuestion();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 18, bottom: 90 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Row() {
            Button(`打开答题卡 · 已答 ${this.answeredCount()}/${this.session.questions.length}`)
              .width('100%')
              .height(50)
              .borderRadius(22)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#2D75FF')
              .onClick(() => {
                this.showAnswerCard = true;
              })
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 16 })
          .backgroundColor('#F6F8FC')
        } else {
          Column() {
            Text('暂无题目')
              .fontSize(16)
              .fontColor('#64748B')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F8FC')

      if (this.showAnswerCard) {
        Column() {
          Blank().layoutWeight(1)
          this.AnswerCardPanel()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}