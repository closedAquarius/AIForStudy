import { router } from '@kit.ArkUI';
import {
  FavoriteQuestionItem,
  getFavoriteQuestions,
  updateQuestionPersonalRecord
} from '../common/ApiClient';
import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct FavoriteQuestionPage {
  @State loading: boolean = false;
  @State savingId: number = 0;
  @State questions: FavoriteQuestionItem[] = [];
  @State keyword: string = '';
  @State expandedId: number = 0;
  @State editingId: number = 0;
  @State noteText: string = '';
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
      const result = await getFavoriteQuestions(this.getToken(), this.keyword.trim(), 1, 100);
      if (result.success && result.data) {
        this.questions = result.data.questions;
        if (this.questions.length === 0) {
          this.message = this.keyword.trim().length > 0 ? '没有匹配的收藏题目' : '还没有收藏题目';
        }
      } else {
        this.message = result.message || '收藏题目加载失败';
      }
    } catch (error) {
      this.message = `收藏题目加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
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
    if (type === 'blank') {
      return '填空题';
    }
    if (type === 'short_answer') {
      return '简答题';
    }
    return type.length > 0 ? type : '题目';
  }

  private startEdit(question: FavoriteQuestionItem): void {
    this.editingId = question.id;
    this.noteText = question.note;
  }

  private replaceNote(questionId: number, note: string): void {
    const next: FavoriteQuestionItem[] = [];
    for (let i = 0; i < this.questions.length; i++) {
      const item = this.questions[i];
      if (item.id === questionId) {
        const updated: FavoriteQuestionItem = {
          id: item.id,
          type: item.type,
          stem: item.stem,
          analysis: item.analysis,
          difficulty: item.difficulty,
          knowledgePoint: item.knowledgePoint,
          bankName: item.bankName,
          note: note,
          updatedAt: item.updatedAt
        };
        next.push(updated);
      } else {
        next.push(item);
      }
    }
    this.questions = next;
  }

  private async saveNote(question: FavoriteQuestionItem): Promise<void> {
    if (this.savingId > 0) {
      return;
    }
    this.savingId = question.id;
    try {
      const result = await updateQuestionPersonalRecord(
        this.getToken(),
        question.id,
        true,
        this.noteText.trim()
      );
      if (result.success && result.data) {
        this.replaceNote(question.id, result.data.note);
        this.editingId = 0;
        this.message = '笔记已保存';
      } else {
        this.message = result.message || '笔记保存失败';
      }
    } catch (error) {
      this.message = `笔记保存失败：${(error as Error).message}`;
    } finally {
      this.savingId = 0;
    }
  }

  private async removeFavorite(question: FavoriteQuestionItem): Promise<void> {
    if (this.savingId > 0) {
      return;
    }
    this.savingId = question.id;
    try {
      const result = await updateQuestionPersonalRecord(
        this.getToken(),
        question.id,
        false,
        question.note
      );
      if (result.success) {
        const next: FavoriteQuestionItem[] = [];
        for (let i = 0; i < this.questions.length; i++) {
          if (this.questions[i].id !== question.id) {
            next.push(this.questions[i]);
          }
        }
        this.questions = next;
        this.message = '已取消收藏';
      } else {
        this.message = result.message || '取消收藏失败';
      }
    } catch (error) {
      this.message = `取消收藏失败：${(error as Error).message}`;
    } finally {
      this.savingId = 0;
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
  QuestionCard(question: FavoriteQuestionItem) {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        this.Tag(this.typeText(question.type), '#2563EB')
        this.Tag(`难度 ${question.difficulty}`, '#D97706')
        Blank()
        Text(question.bankName)
          .fontSize(11)
          .fontColor('#64748B')
          .maxLines(1)
      }
      .width('100%')

      Text(question.stem)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .lineHeight(23)
        .fontColor('#0B1B44')

      if (question.knowledgePoint.length > 0) {
        Text(`知识点：${question.knowledgePoint}`)
          .width('100%')
          .fontSize(11)
          .fontColor('#64748B')
      }

      if (question.note.length > 0 && this.editingId !== question.id) {
        Text(`我的笔记：${question.note}`)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#475569')
          .padding(10)
          .backgroundColor('#FFF9E8')
          .borderRadius(8)
      }

      if (this.expandedId === question.id) {
        Text(question.analysis.length > 0 ? question.analysis : '这道题暂时没有解析。')
          .width('100%')
          .fontSize(13)
          .lineHeight(21)
          .fontColor('#475569')
          .padding(10)
          .backgroundColor('#F8FAFD')
          .borderRadius(8)
      }

      if (this.editingId === question.id) {
        TextArea({ placeholder: '记录解题思路、易错点或复习提醒', text: this.noteText })
          .width('100%')
          .height(120)
          .fontSize(13)
          .backgroundColor('#F8FAFC')
          .borderRadius(8)
          .padding(10)
          .onChange((value: string) => {
            this.noteText = value;
          })

        Row({ space: 8 }) {
          Button('取消')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor('#64748B')
            .backgroundColor('#F1F5F9')
            .borderRadius(8)
            .onClick(() => {
              this.editingId = 0;
            })
          Button(this.savingId === question.id ? '保存中...' : '保存')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(8)
            .enabled(this.savingId === 0)
            .onClick(() => {
              this.saveNote(question);
            })
        }
        .width('100%')
      } else {
        Row({ space: 8 }) {
          Button(this.expandedId === question.id ? '收起解析' : '查看解析')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor('#2563EB')
            .backgroundColor('#EEF5FF')
            .borderRadius(8)
            .onClick(() => {
              this.expandedId = this.expandedId === question.id ? 0 : question.id;
            })
          Button(question.note.length > 0 ? '编辑笔记' : '添加笔记')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor('#B45309')
            .backgroundColor('#FFF7E6')
            .borderRadius(8)
            .onClick(() => {
              this.startEdit(question);
            })
          Button('取消收藏')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontColor('#DC2626')
            .backgroundColor('#FFF1F2')
            .borderRadius(8)
            .enabled(this.savingId === 0)
            .onClick(() => {
              this.removeFavorite(question);
            })
        }
        .width('100%')
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
        title: '我的收藏',
        themeColor: '#D97706'
      })

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索题目、题库、知识点或笔记', text: this.keyword })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .backgroundColor('#F3F5F8')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            this.loadQuestions();
          })

        Button('搜索')
          .width(64)
          .height(42)
          .fontSize(13)
          .fontColor('#B45309')
          .backgroundColor('#FFF7E6')
          .borderRadius(8)
          .onClick(() => {
            this.loadQuestions();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')

      if (this.message.length > 0) {
        Text(this.message)
          .width('100%')
          .fontSize(12)
          .fontColor(this.message.includes('失败') ? '#DC2626' : '#64748B')
          .textAlign(TextAlign.Center)
          .padding({ top: 7, bottom: 7 })
      }

      if (this.loading) {
        Text('正在加载收藏题目...')
          .width('100%')
          .fontSize(13)
          .fontColor('#64748B')
          .textAlign(TextAlign.Center)
          .padding({ top: 28 })
      } else if (this.questions.length === 0) {
        Column({ space: 10 }) {
          Text(this.keyword.trim().length > 0 ? '没有匹配的题目' : '收藏夹是空的')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')
          Text('刷题时点击“收藏”，题目就会出现在这里。')
            .fontSize(13)
            .fontColor('#64748B')
          Button('去刷题')
            .width(120)
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PracticePage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.questions, (question: FavoriteQuestionItem) => {
              this.QuestionCard(question)
            }, (question: FavoriteQuestionItem) => question.id.toString())
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
