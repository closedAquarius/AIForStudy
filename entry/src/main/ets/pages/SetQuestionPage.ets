import { fileIo, picker } from '@kit.CoreFileKit';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import { generateQuestionsFromFile, GeneratedQuestion, UploadGenerateOptions } from '../common/ApiClient';

@Entry
@Component
struct SetQuestionPage {
  @State subject: string = '软件项目管理';
  @State choiceCountText: string = '3';
  @State shortAnswerCountText: string = '2';
  @State judgeCountText: string = '1';
  @State totalScoreText: string = '20';
  @State difficultyText: string = '3';
  @State extraPrompt: string = '围绕课程核心知识点出题，适合作为课堂练习';
  @State selectedFileName: string = '未选择文件';
  @State selectedFileUri: string = '';
  @State uploadFilePath: string = '';
  @State message: string = '';
  @State uploadProgress: string = '';
  @State loading: boolean = false;
  @State generatedQuestions: GeneratedQuestion[] = [];

  private toNumber(value: string, fallback: number): number {
    const parsed = Number(value);
    if (Number.isNaN(parsed)) {
      return fallback;
    }
    return Math.max(0, Math.floor(parsed));
  }

  private difficulty(): number {
    const parsed = this.toNumber(this.difficultyText, 3);
    return Math.max(1, Math.min(parsed, 5));
  }

  private questionCount(): number {
    return this.toNumber(this.choiceCountText, 0)
      + this.toNumber(this.shortAnswerCountText, 0)
      + this.toNumber(this.judgeCountText, 0);
  }

  private questionTypes(): string[] {
    const types: string[] = [];
    if (this.toNumber(this.choiceCountText, 0) > 0) {
      types.push('single_choice');
    }
    if (this.toNumber(this.judgeCountText, 0) > 0) {
      types.push('true_false');
    }
    if (this.toNumber(this.shortAnswerCountText, 0) > 0) {
      types.push('short_answer');
    }
    return types;
  }

  private async selectDocument(): Promise<void> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['.doc', '.docx', '.ppt', '.pptx', '.pdf', '.txt'];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select(options);
      if (result.length > 0) {
        this.selectedFileUri = result[0];
        const parts = result[0].split('/');
        const rawName = parts.length > 0 ? parts[parts.length - 1] : result[0];
        this.selectedFileName = decodeURIComponent(rawName);
        this.uploadFilePath = this.copyToCache(result[0], this.selectedFileName);
        this.message = '文件已选择，可以直接生成题目。';
      }
    } catch (error) {
      this.message = `选择文件失败：${(error as Error).message}`;
    }
  }

  private async submitGenerate(): Promise<void> {
    if (this.loading) {
      return;
    }

    if (this.uploadFilePath.length === 0) {
      this.message = '请先选择 Word、PPT、PDF 或 TXT 课程文档。';
      return;
    }

    const count = this.questionCount();
    if (count <= 0) {
      this.message = '请至少设置一种题型的数量。';
      return;
    }

    this.loading = true;
    this.message = '正在上传文件并调用 AI 生成题目...';
    this.uploadProgress = '文件上传中';
    this.generatedQuestions = [];

    try {
      const options: UploadGenerateOptions = {
        subject: this.subject.trim(),
        questionCount: count,
        questionTypes: this.questionTypes(),
        difficulty: this.difficulty(),
        extraPrompt: `总分 ${this.totalScoreText} 分；选择题 ${this.choiceCountText} 道；判断题 ${this.judgeCountText} 道；简答题 ${this.shortAnswerCountText} 道。${this.extraPrompt}`,
        saveToDb: true,
        ownerUserId: 1
      };
      const result = await generateQuestionsFromFile(
        this.uploadFilePath,
        this.selectedFileName,
        options
      );

      if (result.success && result.data) {
        this.generatedQuestions = result.data.questions;
        if (result.data.saved) {
          const textInfo = result.data.document ? `解析文本 ${result.data.document.text_length} 字，` : '';
          this.message = `${textInfo}生成并保存成功，共 ${result.data.saved.saved_count} 道题，题库ID：${result.data.saved.question_bank_id}。`;
        } else {
          this.message = `生成成功，共 ${this.generatedQuestions.length} 道题。`;
        }
        return;
      }

      this.message = result.message || '生成失败，请稍后重试。';
    } catch (error) {
      this.message = `请求失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
      this.uploadProgress = '';
    }
  }

  @Builder
  SectionTitle(title: string, subtitle: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
      Text(subtitle)
        .fontSize(12)
        .fontColor('#7B8497')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  NumberField(label: string, valueType: string, placeholderText: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor('#65718E')
      TextInput({ placeholder: placeholderText, text: this.getFieldValue(valueType) })
        .height(44)
        .type(InputType.Number)
        .fontSize(16)
        .fontColor('#0B1B44')
        .backgroundColor('#F6F8FC')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.setFieldValue(valueType, value);
        })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  private getFieldValue(valueType: string): string {
    if (valueType === 'choice') {
      return this.choiceCountText;
    }
    if (valueType === 'judge') {
      return this.judgeCountText;
    }
    if (valueType === 'short') {
      return this.shortAnswerCountText;
    }
    if (valueType === 'score') {
      return this.totalScoreText;
    }
    return this.difficultyText;
  }

  private setFieldValue(valueType: string, value: string): void {
    if (valueType === 'choice') {
      this.choiceCountText = value;
      return;
    }
    if (valueType === 'judge') {
      this.judgeCountText = value;
      return;
    }
    if (valueType === 'short') {
      this.shortAnswerCountText = value;
      return;
    }
    if (valueType === 'score') {
      this.totalScoreText = value;
      return;
    }
    this.difficultyText = value;
  }

  @Builder
  ResultItem(question: GeneratedQuestion, index: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`${index + 1}. ${this.typeLabel(question.type)}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#38C98A')
          .layoutWeight(1)
        Text(`${question.score} 分`)
          .fontSize(12)
          .fontColor('#7B8497')
      }

      Text(question.stem)
        .fontSize(15)
        .fontColor('#0B1B44')
        .lineHeight(22)

      if (question.analysis.length > 0) {
        Text(`解析：${question.analysis}`)
          .fontSize(12)
          .fontColor('#65718E')
          .lineHeight(18)
          .maxLines(3)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
  }

  private typeLabel(type: string): string {
    if (type === 'single_choice') {
      return '选择题';
    }
    if (type === 'true_false') {
      return '判断题';
    }
    if (type === 'short_answer') {
      return '简答题';
    }
    if (type === 'blank') {
      return '填空题';
    }
    if (type === 'multiple_choice') {
      return '多选题';
    }
    return '题目';
  }

  private copyToCache(sourceUri: string, fileName: string): string {
    const cacheFileName = `upload-${new Date().getTime()}${this.fileSuffix(fileName)}`;
    const cachePath = `${getContext(this).cacheDir}/${cacheFileName}`;
    const sourceFile = fileIo.openSync(sourceUri);
    const cacheFile = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    fileIo.copyFileSync(sourceFile.fd, cacheFile.fd);
    fileIo.closeSync(sourceFile);
    fileIo.closeSync(cacheFile);
    return cachePath;
  }

  private fileSuffix(fileName: string): string {
    const index = fileName.lastIndexOf('.');
    if (index < 0) {
      return '';
    }
    return fileName.substring(index);
  }

  build() {
    Column() {
      FeaturePageHeader({
        title: '文档出题',
        themeColor: '#38C98A'
      })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 14 }) {
            this.SectionTitle('出题配置', '设置题型数量、难度和总分，AI 会按这些要求生成题目')

            TextInput({ placeholder: '学科 / 课程名称', text: this.subject })
              .height(46)
              .fontSize(16)
              .fontColor('#0B1B44')
              .backgroundColor('#F6F8FC')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.subject = value;
              })

            Row({ space: 10 }) {
              this.NumberField('选择题', 'choice', '0')
              this.NumberField('判断题', 'judge', '0')
              this.NumberField('简答题', 'short', '0')
            }
            .width('100%')

            Row({ space: 10 }) {
              this.NumberField('总分', 'score', '20')
              this.NumberField('难度 1-5', 'difficulty', '3')
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#EEF2F7' })

          Column({ space: 14 }) {
            this.SectionTitle('上传资料', '通过系统文件选择器选择 Word、PPT、PDF 或 TXT')

            Button() {
              Row({ space: 8 }) {
                Text('+')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                Text('选择课程文档')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .height(48)
            .borderRadius(8)
            .backgroundColor('#38C98A')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.selectDocument();
            })

            Column({ space: 5 }) {
              Text(this.selectedFileName)
                .fontSize(13)
                .fontColor('#0B1B44')
                .maxLines(1)
              if (this.selectedFileUri.length > 0) {
                Text(this.selectedFileUri)
                  .fontSize(11)
                  .fontColor('#9CA3AF')
                  .maxLines(1)
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(8)
            .backgroundColor('#F6F8FC')

            TextInput({ placeholder: '额外要求，例如偏基础、适合期末复习、覆盖重点概念', text: this.extraPrompt })
              .height(46)
              .fontSize(14)
              .fontColor('#0B1B44')
              .backgroundColor('#F6F8FC')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.extraPrompt = value;
              })
          }
          .width('100%')
          .padding(16)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#EEF2F7' })

          Button(this.loading ? '生成中...' : `生成 ${this.questionCount()} 道题`)
            .width('100%')
            .height(50)
            .borderRadius(8)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#0B1B44')
            .fontColor('#FFFFFF')
            .enabled(!this.loading)
            .onClick(() => {
              this.submitGenerate();
            })

          if (this.message.length > 0) {
            Text(this.message)
              .width('100%')
              .fontSize(13)
              .fontColor(this.message.includes('成功') || this.message.includes('正在') || this.message.includes('已选择') ? '#047857' : '#DC2626')
              .textAlign(TextAlign.Center)
          }

          if (this.uploadProgress.length > 0) {
            Text(this.uploadProgress)
              .width('100%')
              .fontSize(12)
              .fontColor('#65718E')
              .textAlign(TextAlign.Center)
          }

          if (this.generatedQuestions.length > 0) {
            Column({ space: 12 }) {
              this.SectionTitle('生成结果', '以下为 AI 返回的题目预览，后续可继续接入保存题库')
              ForEach(this.generatedQuestions, (item: GeneratedQuestion, index: number) => {
                this.ResultItem(item, index)
              }, (item: GeneratedQuestion, index: number) => `${index}-${item.stem}`)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 18 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F6F8FC')

      FeatureBottomNav({
        selectedIndex: 2
      })
    }
    .width('100%')
    .height('100%')
  }
}
