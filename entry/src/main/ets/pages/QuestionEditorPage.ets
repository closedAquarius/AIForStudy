import { router } from '@kit.ArkUI';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import {
  QuestionEditOption,
  QuestionEditRequest,
  QuestionEditorItem,
  batchUpdateQuestions,
  createQuestion,
  deleteQuestion,
  getQuestionEditorList,
  updateQuestion
} from '../common/ApiClient';

interface QuestionEditorParams {
  bankId?: string;
}

@Entry
@Component
struct QuestionEditorPage {
  @State bankId: number = 0;
  @State bankName: string = '题目编辑器';
  @State questions: QuestionEditorItem[] = [];
  @State selectedIds: number[] = [];
  @State loading: boolean = false;
  @State showEditor: boolean = false;
  @State editingId: number = 0;
  @State type: string = 'single_choice';
  @State stem: string = '';
  @State analysis: string = '';
  @State difficultyText: string = '3';
  @State scoreText: string = '1';
  @State knowledgePoint: string = '';
  @State answerText: string = '';
  @State status: string = 'active';
  @State optionA: string = '';
  @State optionB: string = '';
  @State optionC: string = '';
  @State optionD: string = '';
  @State batchScoreText: string = '2';

  aboutToAppear(): void {
    const params = router.getParams() as QuestionEditorParams;
    this.bankId = Number(params?.bankId ?? '0');
    this.loadQuestions();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private showTip(message: string): void {
    AlertDialog.show({
      title: '提示',
      message: message,
      primaryButton: { value: '知道了', action: () => {} }
    });
  }

  private async loadQuestions(): Promise<void> {
    if (this.bankId <= 0) {
      return;
    }
    this.loading = true;
    try {
      const result = await getQuestionEditorList(this.getToken(), this.bankId);
      if (result.success && result.data) {
        this.bankName = result.data.bankName;
        this.questions = result.data.questions;
        this.selectedIds = [];
      } else {
        this.showTip(result.message);
      }
    } catch (error) {
      this.showTip(`加载失败：${(error as Error).message}`);
    } finally {
      this.loading = false;
    }
  }

  private optionValue(question: QuestionEditorItem, key: string): string {
    for (let i = 0; i < question.options.length; i++) {
      if (question.options[i].optionKey === key) {
        return question.options[i].content;
      }
    }
    return '';
  }

  private openCreate(): void {
    this.editingId = 0;
    this.type = 'single_choice';
    this.stem = '';
    this.analysis = '';
    this.difficultyText = '3';
    this.scoreText = '1';
    this.knowledgePoint = '';
    this.answerText = '';
    this.status = 'active';
    this.optionA = '';
    this.optionB = '';
    this.optionC = '';
    this.optionD = '';
    this.showEditor = true;
  }

  private openEdit(question: QuestionEditorItem): void {
    this.editingId = question.id;
    this.type = question.type;
    this.stem = question.stem;
    this.analysis = question.analysis;
    this.difficultyText = question.difficulty.toString();
    this.scoreText = question.score.toString();
    this.knowledgePoint = question.knowledgePoint;
    this.answerText = question.answerText;
    this.status = question.status;
    this.optionA = this.optionValue(question, 'A');
    this.optionB = this.optionValue(question, 'B');
    this.optionC = this.optionValue(question, 'C');
    this.optionD = this.optionValue(question, 'D');
    this.showEditor = true;
  }

  private isChoice(): boolean {
    return this.type === 'single_choice' || this.type === 'multiple_choice';
  }

  private buildOptions(): QuestionEditOption[] {
    const result: QuestionEditOption[] = [];
    const values: string[] = [this.optionA, this.optionB, this.optionC, this.optionD];
    const keys: string[] = ['A', 'B', 'C', 'D'];
    for (let i = 0; i < values.length; i++) {
      if (values[i].trim().length > 0) {
        result.push({ option_key: keys[i], content: values[i].trim() });
      }
    }
    return result;
  }

  private async saveQuestion(): Promise<void> {
    const payload: QuestionEditRequest = {
      type: this.type,
      stem: this.stem.trim(),
      analysis: this.analysis.trim(),
      difficulty: Number(this.difficultyText),
      score: Number(this.scoreText),
      knowledge_point: this.knowledgePoint.trim(),
      answer_text: this.answerText.trim(),
      status: this.status,
      options: this.buildOptions()
    };
    try {
      const result = this.editingId > 0
        ? await updateQuestion(this.getToken(), this.editingId, payload)
        : await createQuestion(this.getToken(), this.bankId, payload);
      this.showTip(result.message);
      if (result.success) {
        this.showEditor = false;
        await this.loadQuestions();
      }
    } catch (error) {
      this.showTip(`保存失败：${(error as Error).message}`);
    }
  }

  private selected(id: number): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelect(id: number): void {
    if (this.selected(id)) {
      this.selectedIds = this.selectedIds.filter((item: number) => item !== id);
    } else {
      this.selectedIds = [...this.selectedIds, id];
    }
  }

  private async batchAction(action: string): Promise<void> {
    if (this.selectedIds.length === 0) {
      this.showTip('请先选择题目');
      return;
    }
    const score = action === 'score' ? Number(this.batchScoreText) : 0;
    const result = await batchUpdateQuestions(this.getToken(), this.bankId, this.selectedIds, action, score);
    this.showTip(result.message);
    if (result.success) {
      await this.loadQuestions();
    }
  }

  private async removeQuestion(id: number): Promise<void> {
    const result = await deleteQuestion(this.getToken(), id);
    this.showTip(result.message);
    if (result.success) {
      await this.loadQuestions();
    }
  }

  private typeOptions(): SelectOption[] {
    return [
      { value: '单选题' }, { value: '多选题' }, { value: '判断题' },
      { value: '填空题' }, { value: '简答题' }, { value: '论述题' }
    ];
  }

  private typeIndex(): number {
    const types: string[] = ['single_choice', 'multiple_choice', 'true_false', 'blank', 'short_answer', 'essay'];
    return Math.max(0, types.indexOf(this.type));
  }

  @Builder
  QuestionCard(question: QuestionEditorItem) {
    Row({ space: 12 }) {
      Text(this.selected(question.id) ? '✓' : '')
        .width(26)
        .height(26)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor(this.selected(question.id) ? '#2D75FF' : '#DCE4F0')
        .onClick(() => this.toggleSelect(question.id))

      Column({ space: 7 }) {
        Row({ space: 7 }) {
          Text(question.typeLabel).fontSize(12).fontColor('#2D75FF')
          Text(`${question.score} 分`).fontSize(12).fontColor('#64748B')
          if (question.aiGenerated === 1) {
            Text('AI').fontSize(11).fontColor('#7C3AED')
          }
          Text(question.status === 'draft' ? '待审核' : '已发布')
            .fontSize(11)
            .fontColor(question.status === 'draft' ? '#B45309' : '#16805A')
        }
        Text(question.stem)
          .width('100%')
          .fontSize(15)
          .fontColor('#0B1B44')
          .maxLines(2)
        Text(`答案：${question.answerText}`)
          .width('100%')
          .fontSize(12)
          .fontColor('#64748B')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.openEdit(question))

      Button('删除')
        .width(54)
        .height(32)
        .fontSize(11)
        .fontColor('#EF4444')
        .backgroundColor('#FFF1F2')
        .borderRadius(6)
        .onClick(() => this.removeQuestion(question.id))
    }
    .width('100%')
    .padding(14)
    .backgroundColor(question.status === 'draft' ? '#FFFBEB' : '#FFFFFF')
    .border({ width: 1, color: question.status === 'draft' ? '#FDE68A' : '#E5EAF3' })
    .borderRadius(8)
  }

  @Builder
  EditorField(label: string, value: string, field: string) {
    Column({ space: 5 }) {
      Text(label).fontSize(12).fontColor('#64748B')
      TextInput({ text: value })
        .width('100%')
        .height(40)
        .backgroundColor('#F6F8FC')
        .borderRadius(6)
        .onChange((next: string) => {
          if (field === 'score') this.scoreText = next;
          else if (field === 'difficulty') this.difficultyText = next;
          else if (field === 'knowledge') this.knowledgePoint = next;
          else if (field === 'answer') this.answerText = next;
          else if (field === 'A') this.optionA = next;
          else if (field === 'B') this.optionB = next;
          else if (field === 'C') this.optionC = next;
          else if (field === 'D') this.optionD = next;
        })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EditorPanel() {
    Column({ space: 12 }) {
      Row() {
        Text(this.editingId > 0 ? '编辑题目' : '手动新增题目')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#0B1B44')
        Blank()
        Button('关闭').height(32).fontSize(12).onClick(() => this.showEditor = false)
      }
      Select(this.typeOptions())
        .selected(this.typeIndex())
        .width('100%')
        .onSelect((index: number) => {
          const types: string[] = ['single_choice', 'multiple_choice', 'true_false', 'blank', 'short_answer', 'essay'];
          this.type = types[index];
        })
      TextArea({ placeholder: '题干', text: this.stem })
        .width('100%').height(90).backgroundColor('#F6F8FC').borderRadius(6)
        .onChange((value: string) => this.stem = value)
      if (this.isChoice()) {
        Row({ space: 8 }) { this.EditorField('选项 A', this.optionA, 'A'); this.EditorField('选项 B', this.optionB, 'B') }
        Row({ space: 8 }) { this.EditorField('选项 C', this.optionC, 'C'); this.EditorField('选项 D', this.optionD, 'D') }
      }
      this.EditorField(this.isChoice() ? '正确答案，如 A 或 A,C' : '参考答案', this.answerText, 'answer')
      TextArea({ placeholder: '答案解析', text: this.analysis })
        .width('100%').height(80).backgroundColor('#F6F8FC').borderRadius(6)
        .onChange((value: string) => this.analysis = value)
      Row({ space: 8 }) {
        this.EditorField('分值', this.scoreText, 'score')
        this.EditorField('难度 1-5', this.difficultyText, 'difficulty')
        this.EditorField('知识点', this.knowledgePoint, 'knowledge')
      }
      Row({ space: 8 }) {
        Button('保存为草稿')
          .layoutWeight(1).height(42).backgroundColor('#FFF7E6').fontColor('#B45309').borderRadius(6)
          .onClick(() => { this.status = 'draft'; this.saveQuestion(); })
        Button('保存并发布')
          .layoutWeight(1).height(42).backgroundColor('#2D75FF').fontColor('#FFFFFF').borderRadius(6)
          .onClick(() => { this.status = 'active'; this.saveQuestion(); })
      }
    }
    .width('94%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        FeaturePageHeader({ title: this.bankName, themeColor: '#2D75FF' })
        Row({ space: 8 }) {
          Button('+ 新增题目').height(36).fontSize(12).onClick(() => this.openCreate())
          Button('发布已选').height(36).fontSize(12).onClick(() => this.batchAction('publish'))
          TextInput({ placeholder: '统一分值', text: this.batchScoreText })
            .width(78).height(36).type(InputType.Number).onChange((value: string) => this.batchScoreText = value)
          Button('改分').height(36).fontSize(12).onClick(() => this.batchAction('score'))
          Button('删除已选').height(36).fontSize(12).fontColor('#EF4444')
            .backgroundColor('#FFF1F2').onClick(() => this.batchAction('delete'))
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#FFFFFF')

        if (this.loading) {
          LoadingProgress().layoutWeight(1)
        } else {
          List({ space: 10 }) {
            ForEach(this.questions, (question: QuestionEditorItem) => {
              ListItem() { this.QuestionCard(question) }
            }, (question: QuestionEditorItem) => question.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding(12)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%').height('100%').backgroundColor('#F6F8FC')

      if (this.showEditor) {
        Column() { this.EditorPanel() }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#77000000')
      }
    }
    .width('100%').height('100%')
  }
}
