import { fileIo, picker } from '@kit.CoreFileKit';
import {
  AiChatMessageItem,
  AiConversationSummary,
  AiDiaryPlanData,
  AiWrongQuestionItem,
  StudyDiaryHistoryItem,
  chatAiLearning,
  explainWrongQuestion,
  generateStudyPlan,
  getAiConversationMessages,
  getAiLearningConversations,
  getWrongQuestions
} from '../common/ApiClient';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import { FeaturePageHeader } from '../components/FeaturePageHeader';

interface LocalChatMessage {
  role: string;
  content: string;
  attachmentName: string;
  attachmentType: string;
}

@Entry
@Component
struct AiLearningPage {
  @State showSidebar: boolean = false;
  @State showTools: boolean = false;
  @State showWrongPicker: boolean = false;
  @State showPlanPicker: boolean = false;
  @State sidebarOffset: number = -420;
  @State sidebarMaskOpacity: number = 0;

  @State conversations: AiConversationSummary[] = [];
  @State conversationId: number = 0;
  @State messages: LocalChatMessage[] = [];
  @State inputText: string = '';
  @State notice: string = '';
  @State loading: boolean = false;

  @State wrongQuestions: AiWrongQuestionItem[] = [];
  @State attachmentName: string = '';
  @State attachmentPath: string = '';
  @State attachmentType: string = '';
  @State planDaysText: string = '3';

  aboutToAppear(): void {
    this.reloadAll();
  }

  private getToken(): string {
    const token = AppStorage.Get<string>('token');
    return token ? token : '';
  }

  private async reloadAll(): Promise<void> {
    await this.loadConversations();
    await this.loadWrongQuestions();
  }

  private async loadConversations(): Promise<void> {
    try {
      const result = await getAiLearningConversations(this.getToken(), 20);
      if (result.success && result.data) {
        this.conversations = result.data.conversations;
      }
    } catch (error) {
      this.notice = `历史会话加载失败：${(error as Error).message}`;
    }
  }

  private async loadConversationMessages(id: number): Promise<void> {
    if (id <= 0) {
      this.messages = [];
      return;
    }

    try {
      const result = await getAiConversationMessages(this.getToken(), id, 80);
      if (result.success && result.data) {
        const next: LocalChatMessage[] = [];
        result.data.messages.forEach((item: AiChatMessageItem) => {
          next.push({
            role: item.role,
            content: this.cleanAttachmentText(item.content),
            attachmentName: this.extractAttachmentName(item.content),
            attachmentType: this.extractAttachmentType(item.content)
          });
        });
        this.messages = next;
      }
    } catch (error) {
      this.notice = `消息加载失败：${(error as Error).message}`;
    }
  }

  private async openConversation(item: AiConversationSummary): Promise<void> {
    this.conversationId = item.id;
    this.closePanels();
    await this.loadConversationMessages(item.id);
  }

  private newConversation(): void {
    this.conversationId = 0;
    this.messages = [];
    this.inputText = '';
    this.notice = '已开启新对话';
    this.clearAttachment();
    this.closePanels();
  }

  private async loadWrongQuestions(): Promise<void> {
    try {
      const result = await getWrongQuestions(this.getToken(), 0, 30);
      if (result.success && result.data) {
        this.wrongQuestions = result.data.questions;
      } else {
        this.wrongQuestions = [];
      }
    } catch (error) {
      this.wrongQuestions = [];
    }
  }

  private appendMessage(role: string, content: string, attachmentName: string = '', attachmentType: string = ''): void {
    const next: LocalChatMessage[] = [];
    this.messages.forEach((item: LocalChatMessage) => {
      next.push(item);
    });
    next.push({
      role: role,
      content: content,
      attachmentName: attachmentName,
      attachmentType: attachmentType
    });
    this.messages = next;
  }

  private async chooseAttachment(): Promise<void> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = [
        '.ppt', '.pptx', '.doc', '.docx', '.pdf', '.txt',
        '.png', '.jpg', '.jpeg'
      ];

      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select(options);
      if (result.length === 0) {
        return;
      }

      const sourceUri = result[0];
      const sourceName = this.extractFileName(sourceUri);
      const cachePath = `${getContext(this).cacheDir}/ai-${new Date().getTime()}${this.fileSuffix(sourceName)}`;
      const sourceFile = fileIo.openSync(sourceUri);
      const cacheFile = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(sourceFile.fd, cacheFile.fd);
      fileIo.closeSync(sourceFile);
      fileIo.closeSync(cacheFile);

      this.attachmentName = sourceName;
      this.attachmentPath = cachePath;
      this.attachmentType = this.fileSuffix(sourceName).replace('.', '');
      this.notice = `已添加附件：${sourceName}`;
      this.showTools = false;
      this.showWrongPicker = false;
      this.showPlanPicker = false;
    } catch (error) {
      this.notice = `附件选择失败：${(error as Error).message}`;
    }
  }

  private clearAttachment(): void {
    this.attachmentName = '';
    this.attachmentPath = '';
    this.attachmentType = '';
  }

  private async sendMessage(): Promise<void> {
    if (this.loading) {
      return;
    }

    const text = this.inputText.trim();
    if (text.length === 0 && this.attachmentPath.length === 0) {
      this.notice = '请输入问题，或点击 + 添加附件。';
      return;
    }

    const userText = text.length > 0 ? text : `请结合附件 ${this.attachmentName} 辅助讲解。`;
    this.loading = true;
    this.notice = 'AI 正在思考...';
    this.appendMessage('user', userText, this.attachmentName, this.attachmentType);

    try {
      const result = await chatAiLearning(
        this.getToken(),
        userText,
        'qa',
        this.conversationId,
        0,
        this.attachmentPath,
        this.attachmentName,
        this.attachmentType
      );

      if (result.success && result.data) {
        this.conversationId = result.data.conversation_id;
        this.appendMessage('assistant', result.data.assistant_message);
        this.inputText = '';
        this.clearAttachment();
        this.notice = '';
        await this.loadConversations();
      } else {
        this.notice = result.message || 'AI 回复失败';
      }
    } catch (error) {
      this.notice = `请求失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private async explainQuestion(question: AiWrongQuestionItem): Promise<void> {
    if (this.loading) {
      return;
    }

    this.loading = true;
    this.showTools = false;
    this.showWrongPicker = false;
    this.showPlanPicker = false;
    this.appendMessage('user', `请讲解这道错题：${question.stem}`);
    this.notice = '正在生成错题讲解...';

    try {
      const result = await explainWrongQuestion(this.getToken(), question.id);
      if (result.success && result.data) {
        this.appendMessage('assistant', result.data.explanation);
        this.notice = '';
      } else {
        this.notice = result.message || '错题讲解失败';
      }
    } catch (error) {
      this.notice = `错题讲解失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private async makeStudyPlan(): Promise<void> {
    if (this.loading) {
      return;
    }

    const days = this.parseDays();
    this.loading = true;
    this.showTools = false;
    this.showWrongPicker = false;
    this.showPlanPicker = false;
    this.appendMessage('user', `请根据我的学习日记，规划未来 ${days} 天的学习方向。`);
    this.notice = '正在分析学习日记...';

    try {
      const result = await generateStudyPlan(this.getToken(), days);
      if (result.success && result.data) {
        this.appendMessage('assistant', this.composePlanAnswer(result.data));
        this.notice = '';
      } else {
        this.notice = result.message || '学习建议生成失败';
      }
    } catch (error) {
      this.notice = `学习建议生成失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private composePlanAnswer(data: AiDiaryPlanData): string {
    const diaryLines: string[] = [];
    data.recent_diaries.forEach((item: StudyDiaryHistoryItem) => {
      diaryLines.push(`${item.entryDate} | 心情 ${item.moodScore} | ${item.title}`);
    });
    if (diaryLines.length === 0) {
      return data.plan;
    }
    return `参考的最近日记：\n${diaryLines.join('\n')}\n\n学习建议：\n${data.plan}`;
  }

  private parseDays(): number {
    const parsed = Number(this.planDaysText);
    if (Number.isNaN(parsed)) {
      return 3;
    }
    return Math.max(1, Math.min(14, Math.floor(parsed)));
  }

  private closePanels(): void {
    this.hideSidebar();
    this.showTools = false;
    this.showWrongPicker = false;
    this.showPlanPicker = false;
  }

  private toggleSidebar(): void {
    if (this.showSidebar) {
      this.hideSidebar();
    } else {
      this.showSidebar = true;
      this.showTools = false;
      this.showWrongPicker = false;
      this.showPlanPicker = false;
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.sidebarOffset = 0;
        this.sidebarMaskOpacity = 1;
      });
    }
  }

  private hideSidebar(): void {
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.sidebarOffset = -420;
      this.sidebarMaskOpacity = 0;
    });
    setTimeout(() => {
      this.showSidebar = false;
    }, 220);
  }

  private toggleTools(): void {
    this.showTools = !this.showTools;
    if (this.showTools) {
      this.showSidebar = false;
      this.showWrongPicker = false;
      this.showPlanPicker = false;
    }
  }

  private toggleWrongPanel(): void {
    this.showWrongPicker = !this.showWrongPicker;
    this.showPlanPicker = false;
  }

  private togglePlanPanel(): void {
    this.showPlanPicker = !this.showPlanPicker;
    this.showWrongPicker = false;
  }

  private extractFileName(uri: string): string {
    const cleaned = uri.split('?')[0];
    const index = cleaned.lastIndexOf('/');
    if (index < 0) {
      return decodeURIComponent(cleaned);
    }
    return decodeURIComponent(cleaned.substring(index + 1));
  }

  private fileSuffix(fileName: string): string {
    const index = fileName.lastIndexOf('.');
    if (index < 0) {
      return '';
    }
    return fileName.substring(index).toLowerCase();
  }

  private isMarkdownHeading(line: string): boolean {
    const text = line.trim();
    return text.startsWith('# ') || text.startsWith('## ') || text.startsWith('### ');
  }

  private formatMarkdownLine(line: string): string {
    let text = line.trim();
    if (text.startsWith('### ')) {
      text = text.substring(4);
    } else if (text.startsWith('## ')) {
      text = text.substring(3);
    } else if (text.startsWith('# ')) {
      text = text.substring(2);
    }
    if (text.startsWith('- ')) {
      text = `- ${text.substring(2)}`;
    }
    return text.split('**').join('').split('__').join('');
  }

  private cleanAttachmentText(content: string): string {
    const index = content.indexOf('附件信息：');
    if (index < 0) {
      return content;
    }
    return content.substring(0, index).trim();
  }

  private extractAttachmentName(content: string): string {
    const jsonText = this.extractAttachmentJson(content);
    if (jsonText.length === 0) {
      return '';
    }
    const fileName = this.extractJsonStringField(jsonText, 'file_name');
    if (fileName.length > 0) {
      return fileName;
    }
    return this.extractJsonStringField(jsonText, 'original_name');
  }

  private extractAttachmentType(content: string): string {
    const jsonText = this.extractAttachmentJson(content);
    if (jsonText.length === 0) {
      return '';
    }
    const fileType = this.extractJsonStringField(jsonText, 'file_type');
    if (fileType.length > 0) {
      return fileType;
    }
    return this.extractJsonStringField(jsonText, 'attachment_type');
  }

  private extractAttachmentJson(content: string): string {
    const index = content.indexOf('附件信息：');
    if (index < 0) {
      return '';
    }
    return content.substring(index + 5).trim();
  }

  private extractJsonStringField(jsonText: string, key: string): string {
    const keyIndex = jsonText.indexOf(`"${key}"`);
    if (keyIndex < 0) {
      return '';
    }
    const colonIndex = jsonText.indexOf(':', keyIndex);
    if (colonIndex < 0) {
      return '';
    }
    const startQuote = jsonText.indexOf('"', colonIndex + 1);
    if (startQuote < 0) {
      return '';
    }
    const endQuote = jsonText.indexOf('"', startQuote + 1);
    if (endQuote < 0) {
      return '';
    }
    return jsonText.substring(startQuote + 1, endQuote);
  }

  @Builder
  SidebarConversationItem(item: AiConversationSummary) {
    Column({ space: 4 }) {
      Text(item.title.length > 0 ? item.title : '未命名对话')
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .maxLines(1)

      Text(item.lastMessage.length > 0 ? this.formatMarkdownLine(item.lastMessage) : item.updatedAt)
        .width('100%')
        .fontSize(11)
        .fontColor('#6B7280')
        .maxLines(2)
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(this.conversationId === item.id ? '#EAF2FF' : '#FFFFFF')
    .border({ width: 1, color: this.conversationId === item.id ? '#A8C7FA' : '#E5E7EB' })
    .onClick(() => {
      this.openConversation(item);
    })
  }

  @Builder
  SidebarPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('历史会话')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)

        Button('+')
          .width(34)
          .height(32)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .borderRadius(8)
          .onClick(() => {
            this.newConversation();
          })
      }
      .width('100%')

      Button('新对话')
        .width('100%')
        .height(36)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2563EB')
        .backgroundColor('#EFF6FF')
        .borderRadius(8)
        .onClick(() => {
          this.newConversation();
        })

      if (this.conversations.length === 0) {
        Text('暂无历史会话')
          .width('100%')
          .fontSize(12)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .padding({ top: 18 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.conversations, (item: AiConversationSummary) => {
              this.SidebarConversationItem(item)
            }, (item: AiConversationSummary) => `${item.id}`)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 18, bottom: 18 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  MarkdownContent(content: string, color: string) {
    Column({ space: 4 }) {
      ForEach(content.split('\n'), (line: string, index: number) => {
        if (this.formatMarkdownLine(line).length > 0) {
          Text(this.formatMarkdownLine(line))
            .width('100%')
            .fontSize(this.isMarkdownHeading(line) ? 15 : 14)
            .fontWeight(this.isMarkdownHeading(line) ? FontWeight.Bold : FontWeight.Normal)
            .lineHeight(22)
            .fontColor(color)
        }
      }, (line: string, index: number) => `${index}-${line}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MessageAttachmentCard(message: LocalChatMessage) {
    if (message.attachmentName.length > 0) {
      Row({ space: 8 }) {
        Text('FILE')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(message.role === 'assistant' ? '#2563EB' : '#DBEAFE')

        Column({ space: 2 }) {
          Text(message.attachmentName)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(message.role === 'assistant' ? '#111827' : '#FFFFFF')
            .maxLines(1)

          Text(message.attachmentType.length > 0 ? message.attachmentType.toUpperCase() : '附件')
            .fontSize(10)
            .fontColor(message.role === 'assistant' ? '#6B7280' : '#DBEAFE')
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(message.role === 'assistant' ? '#F3F4F6' : '#3654B3')
    }
  }

  @Builder
  MessageBubble(message: LocalChatMessage) {
    Row() {
      if (message.role === 'assistant') {
        Column({ space: 6 }) {
          Text('AI 辅学')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2563EB')

          this.MessageAttachmentCard(message)

          this.MarkdownContent(message.content, '#111827')
        }
        .width('86%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E5E7EB' })

        Blank()
      } else {
        Blank()

        Column({ space: 6 }) {
          this.MessageAttachmentCard(message)

          this.MarkdownContent(message.content, '#FFFFFF')
        }
        .width('86%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#1E3A8A')
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ToolButton(mark: string, title: string, note: string, action: () => void) {
    Column({ space: 4 }) {
      Text(mark)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2563EB')

      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')

      Text(note)
        .fontSize(10)
        .fontColor('#6B7280')
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(78)
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .backgroundColor('#F9FAFB')
    .border({ width: 1, color: '#E5E7EB' })
    .onClick(action)
  }

  @Builder
  WrongQuestionPanel() {
    Column({ space: 8 }) {
      if (this.wrongQuestions.length === 0) {
        Text('暂无错题。刷题后答错的题会出现在这里。')
          .width('100%')
          .fontSize(12)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .padding(12)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.wrongQuestions, (item: AiWrongQuestionItem) => {
              Row({ space: 8 }) {
                Column({ space: 4 }) {
                  Text(item.stem)
                    .fontSize(13)
                    .fontColor('#111827')
                    .maxLines(2)

                  Text(item.knowledgePoint.length > 0 ? item.knowledgePoint : item.bankName)
                    .fontSize(11)
                    .fontColor('#6B7280')
                    .maxLines(1)
                }
                .layoutWeight(1)

                Button('讲解')
                  .width(60)
                  .height(30)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#EF4444')
                  .borderRadius(8)
                  .onClick(() => {
                    this.explainQuestion(item);
                  })
              }
              .width('100%')
              .padding(10)
              .borderRadius(8)
              .backgroundColor('#FFF7ED')
            }, (item: AiWrongQuestionItem) => `${item.id}`)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .height(180)
      }
    }
    .width('100%')
  }

  @Builder
  PlanPanel() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '天数', text: this.planDaysText })
        .layoutWeight(1)
        .height(38)
        .type(InputType.Number)
        .fontSize(13)
        .fontColor('#111827')
        .backgroundColor('#F9FAFB')
        .borderRadius(8)
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.planDaysText = value;
        })

      Button('生成')
        .width(72)
        .height(38)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#F59E0B')
        .borderRadius(8)
        .onClick(() => {
          this.makeStudyPlan();
        })
    }
    .width('100%')
  }

  @Builder
  ToolsPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.ToolButton('+', '附件', '文档/图片', () => {
          this.chooseAttachment();
        })
        this.ToolButton('!', '错题', `${this.wrongQuestions.length} 题`, () => {
          this.toggleWrongPanel();
        })
        this.ToolButton('D', '日记', '学习方向', () => {
          this.togglePlanPanel();
        })
      }
      .width('100%')

      if (this.showWrongPicker) {
        this.WrongQuestionPanel()
      }

      if (this.showPlanPicker) {
        this.PlanPanel()
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#E5E7EB' })
  }

  @Builder
  AttachmentChip() {
    if (this.attachmentName.length > 0) {
      Row({ space: 8 }) {
        Text(this.attachmentName)
          .fontSize(12)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)

        Button('x')
          .width(30)
          .height(28)
          .fontSize(13)
          .fontColor('#6B7280')
          .backgroundColor('#E5E7EB')
          .borderRadius(8)
          .onClick(() => {
            this.clearAttachment();
          })
      }
      .width('100%')
      .padding({ left: 10, right: 8, top: 7, bottom: 7 })
      .borderRadius(8)
      .backgroundColor('#FFFBEB')
    }
  }

  @Builder
  InputBar() {
    Column({ space: 8 }) {
      if (this.showTools) {
        this.ToolsPanel()
      }

      this.AttachmentChip()

      Row({ space: 8 }) {
        TextInput({ placeholder: '问知识点、题目或学习规划', text: this.inputText })
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .fontColor('#111827')
          .backgroundColor('#F3F4F6')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.inputText = value;
          })

        Button('+')
          .width(46)
          .height(46)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
          .backgroundColor('#EFF6FF')
          .borderRadius(8)
          .onClick(() => {
            this.toggleTools();
          })

        Button(this.loading ? '...' : '发')
          .width(46)
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#1E3A8A')
          .borderRadius(8)
          .enabled(!this.loading)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E5E7EB' })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        FeaturePageHeader({
          title: 'AI 辅学',
          themeColor: '#F59E0B'
        })

        Row() {
          Column({ space: 2 }) {
            Text(this.conversationId > 0 ? '继续对话' : '新对话')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')

            Text('附件、错题、日记都在输入框右侧 + 里')
              .fontSize(11)
              .fontColor('#6B7280')
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('☰')
            .width(38)
            .height(36)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .backgroundColor('#F3F4F6')
            .borderRadius(8)
            .onClick(() => {
              this.toggleSidebar();
            })
        }
        .width('100%')
        .height(54)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#E5E7EB' })

        Scroll() {
          Column({ space: 12 }) {
            if (this.messages.length === 0) {
              Column({ space: 10 }) {
                Text('今天想学什么？')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#111827')

                Text('直接提问，或点输入框右侧 + 添加附件、错题讲解和日记规划。')
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor('#6B7280')
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 18, bottom: 18 })
              .alignItems(HorizontalAlign.Start)
              .borderRadius(8)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E5E7EB' })
            } else {
              ForEach(this.messages, (item: LocalChatMessage, index: number) => {
                this.MessageBubble(item)
              }, (item: LocalChatMessage, index: number) => `${index}-${item.role}`)
            }

            if (this.notice.length > 0) {
              Text(this.notice)
                .width('100%')
                .fontSize(12)
                .fontColor(this.notice.indexOf('失败') >= 0 ? '#DC2626' : '#6B7280')
                .textAlign(TextAlign.Center)
                .padding({ top: 4, bottom: 4 })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .backgroundColor('#F6F8FC')

        this.InputBar()

        FeatureBottomNav({
          selectedIndex: 4
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)

      if (this.showSidebar) {
        Row() {
          Column() {
            this.SidebarPanel()
          }
          .width('34%')
          .height('100%')
          .backgroundColor('#FFFFFF')
          .translate({ x: this.sidebarOffset, y: 0 })
          .animation({ duration: 260, curve: Curve.EaseOut })

          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor('#00000055')
            .opacity(this.sidebarMaskOpacity)
            .animation({ duration: 220, curve: Curve.EaseOut })
            .onClick(() => {
              this.hideSidebar();
            })
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .height('100%')
  }
}
