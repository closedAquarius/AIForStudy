import { router } from '@kit.ArkUI';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import {
  QuestionListData,
  QuestionListItem,
  QuestionListQuery,
  QuestionTypeOption,
  QuestionOptionItem,
  QuestionImportResult,
  getQuestionList,
  importQuestionsFromExcel
} from '../common/ApiClient';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';


interface QuestionListParams {
  bankId?: string;
}

@Entry
@Component
struct QuestionListPage {
  @State bankId: number = 0;
  @State bankName: string = '题目列表';

  @State loading: boolean = false;
  @State questions: QuestionListItem[] = [];
  @State typeOptions: QuestionTypeOption[] = [];
  @State knowledgeOptions: string[] = [];

  @State keyword: string = '';
  @State selectedType: string = '';
  @State selectedDifficulty: number = 0;
  @State knowledgePoint: string = '';
  @State practiceStatus: string = 'all';
  @State wrongOnly: boolean = false;

  @State currentPage: number = 1;
  @State pageSize: number = 10;
  @State total: number = 0;
  @State pageCount: number = 1;
  @State pageInput: string = '1';

  @State expandedIds: number[] = [];

  @State showImportDialog: boolean = false;
  @State importStage: string = 'choose'; // choose | importing | success | failed
  @State selectedFilePath: string = '';
  @State selectedFileName: string = '';
  @State importProgress: number = 0;
  @State importError: string = '';
  @State importSummary: string = '';
  @State progressTimerId: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as QuestionListParams;
    if (params) {
      this.bankId = Number(params.bankId ?? '0');
    }
    this.loadQuestions();
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

  private async loadQuestions(): Promise<void> {
    if (this.bankId <= 0) {
      this.showTip('题库参数错误');
      return;
    }

    this.loading = true;

    const query: QuestionListQuery = {
      bankId: this.bankId,
      page: this.currentPage,
      pageSize: this.pageSize,
      keyword: this.keyword.trim(),
      type: this.selectedType,
      difficulty: this.selectedDifficulty,
      knowledgePoint: this.knowledgePoint.trim(),
      practiceStatus: this.practiceStatus,
      wrongOnly: this.wrongOnly
    };

    try {
      const result = await getQuestionList(this.getToken(), query);

      if (result.success && result.data) {
        const data: QuestionListData = result.data;
        this.bankName = data.bank.name;
        this.questions = data.questions;
        this.typeOptions = data.filters.types;
        this.knowledgeOptions = data.filters.knowledgePoints;
        this.currentPage = data.pagination.page;
        this.pageInput = data.pagination.page.toString();
        this.total = data.pagination.total;
        this.pageCount = data.pagination.pageCount;
      } else {
        this.showTip(result.message || '题目列表加载失败');
      }
    } catch (error) {
      this.showTip(`题目列表加载失败：${(error as Error).message}`);
    } finally {
      this.loading = false;
    }
  }

  private reloadFromFirstPage(): void {
    this.currentPage = 1;
    this.pageInput = '1';
    this.expandedIds = [];
    this.loadQuestions();
  }

  private isExpanded(questionId: number): boolean {
    return this.expandedIds.indexOf(questionId) >= 0;
  }

  private toggleAnswer(questionId: number): void {
    const index = this.expandedIds.indexOf(questionId);
    const next: number[] = [];

    for (let i = 0; i < this.expandedIds.length; i++) {
      if (i !== index) {
        next.push(this.expandedIds[i]);
      }
    }

    if (index < 0) {
      next.push(questionId);
    }

    this.expandedIds = next;
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

  private statusText(question: QuestionListItem): string {
    if (question.practiceStatus === 'unpracticed') {
      return '未刷';
    }
    if (question.practiceStatus === 'wrong') {
      return '已刷 · 错题';
    }
    return '已刷 · 正确';
  }

  private statusColor(question: QuestionListItem): string {
    if (question.practiceStatus === 'unpracticed') {
      return '#64748B';
    }
    if (question.practiceStatus === 'wrong') {
      return '#EF4444';
    }
    return '#2D75FF';
  }

  private cardBgColor(question: QuestionListItem): string {
    if (question.practiceStatus === 'unpracticed') {
      return '#F1F5F9';
    }
    if (question.practiceStatus === 'wrong') {
      return '#FFF1F2';
    }
    return '#EEF5FF';
  }

  private goPage(page: number): void {
    if (page < 1 || page > this.pageCount || page === this.currentPage) {
      return;
    }

    this.currentPage = page;
    this.pageInput = page.toString();
    this.expandedIds = [];
    this.loadQuestions();
  }

  private jumpToInputPage(): void {
    const page = Number(this.pageInput);
    if (page < 1 || page > this.pageCount) {
      this.showTip(`请输入 1 到 ${this.pageCount} 之间的页码`);
      return;
    }

    this.goPage(page);
  }

  private pageNumbers(): number[] {
    const pages: number[] = [];
    let start = this.currentPage - 2;
    let end = this.currentPage + 2;

    if (start < 1) {
      start = 1;
      end = Math.min(5, this.pageCount);
    }

    if (end > this.pageCount) {
      end = this.pageCount;
      start = Math.max(1, end - 4);
    }

    for (let i = start; i <= end; i++) {
      pages.push(i);
    }

    return pages;
  }

  private getFileNameFromUri(uri: string): string {
    const cleaned = uri.split('?')[0];
    const index = cleaned.lastIndexOf('/');
    if (index < 0) {
      return decodeURIComponent(cleaned);
    }
    return decodeURIComponent(cleaned.substring(index + 1));
  }

  private progressWidth(): string {
    return `${Math.max(0, Math.min(100, this.importProgress))}%`;
  }

  private openImportDialog(): void {
    this.showImportDialog = true;
    this.importStage = 'choose';
    this.selectedFilePath = '';
    this.selectedFileName = '';
    this.importProgress = 0;
    this.importError = '';
    this.importSummary = '';
  }

  private closeImportDialog(): void {
    this.stopProgressTimer();
    this.showImportDialog = false;
  }

  private async chooseExcelFile(): Promise<void> {
    let sourceFile: fs.File | undefined = undefined;
    let targetFile: fs.File | undefined = undefined;

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;

      // 不要设置 selectMode。
      // FILE 是默认值；在手机上显式设置 selectMode 可能触发
      // SystemCapability.FileManagement.UserFileService.FolderSelection 检查。
      // options.selectMode = picker.DocumentSelectMode.FILE;

      options.fileSuffixFilters = [
        'Excel文件(.xlsx,.xls)|.xlsx,.xls'
      ];

      const documentPicker = new picker.DocumentViewPicker(context);
      const result = await documentPicker.select(options);

      if (result.length === 0) {
        return;
      }

      const sourceUri = result[0];
      const fileName = this.getFileNameFromUri(sourceUri);

      // 建议把文件复制到应用沙箱目录，避免后续临时 URI 权限失效
      const targetPath = `${context.cacheDir}/${new Date().getTime()}_${fileName}`;

      sourceFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      targetFile = fs.openSync(
        targetPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );

      fs.copyFileSync(sourceFile.fd, targetFile.fd);

      this.selectedFileName = fileName;
      this.selectedFilePath = targetPath;
    } catch (error) {
      const err = error as BusinessError;
      this.importStage = 'failed';
      this.importError = `文件选择失败：${err.message}`;
    } finally {
      // 避免 copy/open 中途异常导致 fd 泄露
      if (sourceFile !== undefined) {
        try {
          fs.closeSync(sourceFile);
        } catch (_) {
        }
      }

      if (targetFile !== undefined) {
        try {
          fs.closeSync(targetFile);
        } catch (_) {
        }
      }
    }
  }

  private startProgressTimer(): void {
    this.stopProgressTimer();

    this.progressTimerId = setInterval(() => {
      if (this.importProgress < 88) {
        this.importProgress += 4;
      }
    }, 260);
  }

  private stopProgressTimer(): void {
    if (this.progressTimerId >= 0) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = -1;
    }
  }

  private async startImportExcel(): Promise<void> {
    if (this.selectedFilePath.length === 0) {
      this.showTip('请先选择 Excel 文件');
      return;
    }

    this.importStage = 'importing';
    this.importProgress = 8;
    this.importError = '';
    this.importSummary = '';
    this.startProgressTimer();

    try {
      const result = await importQuestionsFromExcel(
        this.getToken(),
        this.bankId,
        this.selectedFilePath,
        this.selectedFileName
      );

      this.stopProgressTimer();
      this.importProgress = 100;

      if (result.success && result.data) {
        const data: QuestionImportResult = result.data;
        this.importStage = 'success';
        this.importSummary = `成功导入 ${data.successRows} 题，失败 ${data.failedRows} 行`;
        await this.loadQuestions();
      } else {
        this.importStage = 'failed';
        this.importError = result.message || '导入失败';
      }
    } catch (error) {
      this.stopProgressTimer();
      this.importStage = 'failed';
      this.importError = `导入失败：${(error as Error).message}`;
    }
  }

  private backToBankDetail(): void {
    this.closeImportDialog();

    router.replaceUrl({
      url: 'pages/QuestionBankDetailPage',
      params: {
        bankId: this.bankId.toString()
      }
    });
  }

  private typeSelectOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部题型' }];

    for (let i = 0; i < this.typeOptions.length; i++) {
      options.push({ value: this.typeOptions[i].label });
    }

    return options;
  }

  private typeSelectedIndex(): number {
    if (this.selectedType.length === 0) {
      return 0;
    }

    for (let i = 0; i < this.typeOptions.length; i++) {
      if (this.typeOptions[i].value === this.selectedType) {
        return i + 1;
      }
    }

    return 0;
  }

  private difficultySelectOptions(): SelectOption[] {
    return [
      { value: '全部难度' },
      { value: '⭐' },
      { value: '⭐⭐' },
      { value: '⭐⭐⭐' },
      { value: '⭐⭐⭐⭐' },
      { value: '⭐⭐⭐⭐⭐' }
    ];
  }

  private knowledgeSelectOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部知识点' }];

    for (let i = 0; i < this.knowledgeOptions.length; i++) {
      options.push({ value: this.knowledgeOptions[i] });
    }

    return options;
  }

  private knowledgeSelectedIndex(): number {
    if (this.knowledgePoint.length === 0) {
      return 0;
    }

    for (let i = 0; i < this.knowledgeOptions.length; i++) {
      if (this.knowledgeOptions[i] === this.knowledgePoint) {
        return i + 1;
      }
    }

    return 0;
  }

  private statusSelectOptions(): SelectOption[] {
    return [
      { value: '全部状态' },
      { value: '已刷' },
      { value: '未刷' }
    ];
  }

  private statusSelectedIndex(): number {
    if (this.practiceStatus === 'practiced') {
      return 1;
    }
    if (this.practiceStatus === 'unpracticed') {
      return 2;
    }
    return 0;
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

      Text(this.bankName)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
        .maxLines(1)

      Button() {
        Image($r('app.media.add'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      }
      .width(42)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#EAF3FF')
      .onClick(() => {
        this.openImportDialog();
      })

      Button('编辑')
        .width(54)
        .height(38)
        .fontSize(12)
        .fontColor('#B45309')
        .backgroundColor('#FFF7E6')
        .borderRadius(8)
        .margin({ left: 6 })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/QuestionEditorPage',
            params: { bankId: this.bankId.toString() }
          });
        })
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
  Chip(label: string, selected: boolean, action: () => void) {
    Text(label)
      .fontSize(13)
      .fontColor(selected ? '#FFFFFF' : '#2D75FF')
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(16)
      .backgroundColor(selected ? '#2D75FF' : '#EAF3FF')
      .onClick(action)
  }

  @Builder
  SearchArea() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        TextInput({ placeholder: '搜索题干或知识点', text: this.keyword })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .borderRadius(18)
          .backgroundColor('#F3F7FF')
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.keyword = value;
          })

        Button('搜索')
          .width(72)
          .height(42)
          .fontSize(14)
          .borderRadius(18)
          .backgroundColor('#2D75FF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.reloadFromFirstPage();
          })
      }
      .width('100%')

      TextInput({ placeholder: '按知识点筛选，例如：函数、语法', text: this.knowledgePoint })
        .width('100%')
        .height(40)
        .fontSize(13)
        .borderRadius(16)
        .backgroundColor('#FFFFFF')
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.knowledgePoint = value;
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 10 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  FilterArea() {
    Row({ space: 8 }) {
      Select(this.typeSelectOptions())
        .selected(this.typeSelectedIndex())
        .height(38)
        .font({ size: 13, weight: FontWeight.Medium })
        .fontColor('#0B1B44')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .onSelect((index: number) => {
          if (index === 0) {
            this.selectedType = '';
          } else {
            this.selectedType = this.typeOptions[index - 1].value;
          }
          this.reloadFromFirstPage();
        })

      Select(this.difficultySelectOptions())
        .selected(this.selectedDifficulty)
        .height(38)
        .font({ size: 13, weight: FontWeight.Medium })
        .fontColor('#0B1B44')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .onSelect((index: number) => {
          this.selectedDifficulty = index;
          this.reloadFromFirstPage();
        })

      Select(this.knowledgeSelectOptions())
        .selected(this.knowledgeSelectedIndex())
        .height(38)
        .font({ size: 13, weight: FontWeight.Medium })
        .fontColor('#0B1B44')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .onSelect((index: number) => {
          if (index === 0) {
            this.knowledgePoint = '';
          } else {
            this.knowledgePoint = this.knowledgeOptions[index - 1];
          }
          this.reloadFromFirstPage();
        })

      Select(this.statusSelectOptions())
        .selected(this.statusSelectedIndex())
        .height(38)
        .font({ size: 13, weight: FontWeight.Medium })
        .fontColor('#0B1B44')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .onSelect((index: number) => {
          if (index === 1) {
            this.practiceStatus = 'practiced';
          } else if (index === 2) {
            this.practiceStatus = 'unpracticed';
          } else {
            this.practiceStatus = 'all';
          }
          this.reloadFromFirstPage();
        })

      Row({ space: 6 }) {
        Stack({ alignContent: Alignment.Center }) {
          Rect()
            .width(18)
            .height(18)
            .radius(5)
            .fill(this.wrongOnly ? '#EF4444' : '#FFFFFF')
            .stroke(this.wrongOnly ? '#EF4444' : '#CBD5E1')
            .strokeWidth(1)

          if (this.wrongOnly) {
            Text('✓')
              .fontSize(13)
              .fontColor('#FFFFFF')
          }
        }

        Text('只显示错题')
          .fontSize(13)
          .fontColor('#EF4444')
      }
      .height(38)
      .padding({ left: 10, right: 10 })
      .borderRadius(14)
      .backgroundColor('#FFF1F2')
      .onClick(() => {
        this.wrongOnly = !this.wrongOnly;
        this.reloadFromFirstPage();
      })
    }
    .width('100%')
    .height(54)
    .padding({ left: 18, right: 18, bottom: 8 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  OptionRow(option: QuestionOptionItem) {
    Row({ space: 8 }) {
      Text(option.optionKey)
        .width(28)
        .height(28)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2D75FF')
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor('#EAF3FF')

      Text(option.content)
        .layoutWeight(1)
        .fontSize(14)
        .fontColor('#334155')
        .lineHeight(21)
    }
    .width('100%')
  }

  @Builder
  QuestionCard(question: QuestionListItem) {
    Column({ space: 12 }) {
      Row() {
        Text(`#${question.seq}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(14)
          .backgroundColor('#FFFFFF')

        Text(question.typeLabel)
          .fontSize(13)
          .fontColor('#2D75FF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(14)
          .backgroundColor('#FFFFFF')
          .margin({ left: 8 })

        Text(this.starText(question.difficulty))
          .fontSize(12)
          .margin({ left: 8 })

        Blank()

        Text(this.statusText(question))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusColor(question))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(14)
          .backgroundColor('#FFFFFF')
      }
      .width('100%')

      Text(question.stem)
        .width('100%')
        .fontSize(16)
        .fontColor('#0B1B44')
        .lineHeight(24)

      if (question.options.length > 0) {
        Column({ space: 8 }) {
          ForEach(question.options, (option: QuestionOptionItem) => {
            this.OptionRow(option)
          }, (option: QuestionOptionItem) => option.optionKey)
        }
        .width('100%')
        .padding(12)
        .borderRadius(18)
        .backgroundColor('#F8FBFF')
      }

      Row() {
        Row({ space: 6 }) {
          Image($r('app.media.expand'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)

          Text(this.isExpanded(question.id) ? '收起答案' : '展开答案')
            .fontSize(13)
            .fontColor('#2D75FF')
        }
        .onClick(() => {
          this.toggleAnswer(question.id);
        })

        Blank()
      }
      .width('100%')

      if (this.isExpanded(question.id)) {
        Column({ space: 8 }) {
          Text(`答案：${question.answerText.length > 0 ? question.answerText : '暂无答案'}`)
            .width('100%')
            .fontSize(14)
            .fontColor('#0B1B44')
            .lineHeight(22)

          Text(`解析：${question.analysis.length > 0 ? question.analysis : '暂无解析'}`)
            .width('100%')
            .fontSize(14)
            .fontColor('#64748B')
            .lineHeight(22)
        }
        .width('100%')
        .padding(14)
        .borderRadius(18)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E5EEF9' })
      }

      Row() {
        Text(question.knowledgePoint.length > 0 ? `知识点：${question.knowledgePoint}` : '知识点：暂无')
          .fontSize(12)
          .fontColor('#64748B')
          .layoutWeight(1)
          .maxLines(1)

        if (question.tags.length > 0) {
          Text(question.tags[0])
            .fontSize(12)
            .fontColor('#8B67FF')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(12)
            .backgroundColor('#F3ECFF')
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(22)
    .backgroundColor(this.cardBgColor(question))
    .border({ width: 1, color: '#FFFFFF' })
    .shadow({
      radius: 10,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  ListArea() {
    if (this.loading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)

        Text('正在加载题目...')
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ top: 10 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.questions.length === 0) {
      Column({ space: 10 }) {
        Text('暂无题目')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('可以调整搜索或筛选条件后重试')
          .fontSize(14)
          .fontColor('#64748B')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 14 }) {
        ForEach(this.questions, (question: QuestionListItem) => {
          ListItem() {
            this.QuestionCard(question)
          }
        }, (question: QuestionListItem) => question.id.toString())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  PaginationBar() {
    Row({ space: 6 }) {
      Button('‹')
        .width(34)
        .height(34)
        .borderRadius(14)
        .backgroundColor('#EEF5FF')
        .fontColor('#2D75FF')
        .enabled(this.currentPage > 1)
        .onClick(() => {
          this.goPage(this.currentPage - 1);
        })

      ForEach(this.pageNumbers(), (pageNo: number) => {
        Button(pageNo.toString())
          .width(36)
          .height(34)
          .fontSize(13)
          .borderRadius(14)
          .backgroundColor(this.currentPage === pageNo ? '#2D75FF' : '#EEF5FF')
          .fontColor(this.currentPage === pageNo ? '#FFFFFF' : '#2D75FF')
          .onClick(() => {
            this.goPage(pageNo);
          })
      }, (pageNo: number) => pageNo.toString())

      Button('›')
        .width(34)
        .height(34)
        .borderRadius(14)
        .backgroundColor('#EEF5FF')
        .fontColor('#2D75FF')
        .enabled(this.currentPage < this.pageCount)
        .onClick(() => {
          this.goPage(this.currentPage + 1);
        })

      Blank()

      TextInput({ placeholder: '页码', text: this.pageInput })
        .width(58)
        .height(34)
        .fontSize(13)
        .type(InputType.Number)
        .borderRadius(14)
        .backgroundColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .onChange((value: string) => {
          this.pageInput = value;
        })

      Button('跳转')
        .width(56)
        .height(34)
        .fontSize(13)
        .borderRadius(14)
        .backgroundColor('#2D75FF')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.jumpToInputPage();
        })
    }
    .width('100%')
    .height(54)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#FFFFFF')
    .border({
      width: { top: 1 },
      color: '#EEF2F7'
    })
  }

  @Builder
  ImportProgressBar() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(12)
        .borderRadius(6)
        .backgroundColor('#E5EAF3')

      Column()
        .width(this.progressWidth())
        .height(12)
        .borderRadius(6)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            ['#38C98A', 0.0],
            ['#2D75FF', 1.0]
          ]
        })
    }
    .width('100%')
  }

  @Builder
  UploadChooseView() {
    Column({ space: 18 }) {
      Text('导入 Excel 题目')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Column({ space: 10 }) {
        Image($r('app.media.upload'))
          .width(58)
          .height(58)
          .objectFit(ImageFit.Contain)

        Text(this.selectedFileName.length > 0 ? this.selectedFileName : '上传Excel文件导入题目')
          .fontSize(15)
          .fontColor(this.selectedFileName.length > 0 ? '#2D75FF' : '#64748B')
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      .width('100%')
      .height(178)
      .justifyContent(FlexAlign.Center)
      .borderRadius(24)
      .backgroundColor('#F3F4F6')
      .border({
        width: 1,
        color: '#CBD5E1',
        style: BorderStyle.Dashed
      })
      .onClick(() => {
        this.chooseExcelFile();
      })

      Button('开始导入')
        .width('100%')
        .height(46)
        .borderRadius(18)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#2D75FF')
        .enabled(this.selectedFilePath.length > 0)
        .onClick(() => {
          this.startImportExcel();
        })

      Button('取消')
        .width('100%')
        .height(42)
        .borderRadius(18)
        .fontSize(15)
        .fontColor('#64748B')
        .backgroundColor('#EEF2F7')
        .onClick(() => {
          this.closeImportDialog();
        })
    }
    .width('84%')
    .padding(24)
    .borderRadius(28)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ImportingView() {
    Column({ space: 20 }) {
      Text('正在解析并导入题目')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Text(this.selectedFileName)
        .fontSize(14)
        .fontColor('#64748B')
        .maxLines(1)

      this.ImportProgressBar()

      Text(`${this.importProgress}%`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2D75FF')

      Text('请稍等，系统正在读取 Excel 内容并写入题库')
        .fontSize(13)
        .fontColor('#94A3B8')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
    }
    .width('84%')
    .padding(26)
    .borderRadius(28)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ImportResultView(successResult: boolean) {
    Column({ space: 18 }) {
      Image(successResult ? $r('app.media.happy') : $r('app.media.unhappy'))
        .width(76)
        .height(76)
        .objectFit(ImageFit.Contain)

      Text(successResult ? '题目导入成功' : '题目导入失败')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(successResult ? '#16A34A' : '#EF4444')

      Text(successResult ? this.importSummary : this.importError)
        .fontSize(14)
        .fontColor('#64748B')
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .padding({ left: 8, right: 8 })

      Button('返回')
        .width('100%')
        .height(46)
        .borderRadius(18)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor(successResult ? '#2D75FF' : '#EF4444')
        .onClick(() => {
          this.backToBankDetail();
        })
    }
    .width('84%')
    .padding(26)
    .borderRadius(28)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ImportDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          if (this.importStage === 'choose') {
            this.closeImportDialog();
          }
        })

      if (this.importStage === 'choose') {
        this.UploadChooseView()
      } else if (this.importStage === 'importing') {
        this.ImportingView()
      } else if (this.importStage === 'success') {
        this.ImportResultView(true)
      } else {
        this.ImportResultView(false)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        this.HeaderBar()

        this.SearchArea()

        this.FilterArea()

        Column() {
          this.ListArea()
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F6F8FC')

        this.PaginationBar()

        FeatureBottomNav({
          selectedIndex: 1
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F8FC')

      if (this.showImportDialog) {
        this.ImportDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
