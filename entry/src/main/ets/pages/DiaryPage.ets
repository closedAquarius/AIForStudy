import http from '@ohos.net.http';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import { saveStudyDiary, updateStudyDiary, deleteStudyDiary, polishDiary, CommonResult, StudyDiarySaveData } from '../common/ApiClient';

const API_BASE_URL: string = 'http://192.168.59.1:5000/api';

interface DiaryEntry {
  id: number;
  entryDate: string;
  title: string;
  moodScore: number;
  tags: string[];
  content: string;
}

interface DiaryListResponse {
  success?: boolean;
  message?: string;
  data?: DiaryEntry[];
}

interface RequestHeader {
  'Content-Type': string;
  Authorization: string;
}

class DiaryEntryDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private entries: DiaryEntry[] = [];

  totalCount(): number {
    return this.entries.length;
  }

  getData(index: number): DiaryEntry {
    return this.entries[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  setEntries(entries: DiaryEntry[]): void {
    this.entries = entries;
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }
}

function createRequestHeader(token: string): RequestHeader {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`
  };
}

function fetchDiaryList(token: string): Promise<DiaryEntry[]> {
  return new Promise((resolve: (value: DiaryEntry[]) => void, reject: (reason: Error) => void) => {
    const request = http.createHttp();
    request.request(
      `${API_BASE_URL}/diary/list`,
      {
        method: http.RequestMethod.GET,
        header: createRequestHeader(token),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 8000
      },
      (error, response) => {
        request.destroy();
        if (error) {
          reject(new Error(error.message));
          return;
        }

        try {
          const raw = response.result as string;
          const parsed = JSON.parse(raw) as DiaryEntry[] | DiaryListResponse;
          if (Array.isArray(parsed)) {
            resolve(parsed);
            return;
          }

          if (parsed.success === false) {
            reject(new Error(parsed.message || '历史日记加载失败'));
            return;
          }

          resolve(parsed.data ?? []);
        } catch (parseError) {
          reject(new Error('后端响应解析失败'));
        }
      }
    );
  });
}

@Entry
@Component
struct DiaryPage {
  @State entryDate: string = '';
  @State title: string = '';
  @State moodScore: number = 8;
  @State content: string = '';
  @State selectedTags: string[] = [];
  @State loading: boolean = false;
  @State formMessage: string = '';
  @State formMessageSuccess: boolean = true;

  @State historyLoading: boolean = false;
  @State refreshing: boolean = false;
  @State historyMessage: string = '';
  @State historyCount: number = 0;

  @State showDetail: boolean = false;
  @State showForm: boolean = false;
  @State detailId: number = 0;
  @State detailDate: string = '';
  @State detailTitle: string = '';
  @State detailMoodScore: number = 0;
  @State detailTags: string[] = [];
  @State detailContent: string = '';

  @State editingId: number = 0;
  @State deleting: boolean = false;
  @State listVersion: number = 0;

  @State polishing: boolean = false;
  @State showPolishCompare: boolean = false;
  @State originalContent: string = '';
  @State polishedContent: string = '';

  @State customTagInput: string = '';
  @State showCustomTagInput: boolean = false;
  @State searchKeyword: string = '';

  private allEntries: DiaryEntry[] = [];
  private diarySource: DiaryEntryDataSource = new DiaryEntryDataSource();
  private tagOptions: string[] = [
    '软件工程',
    '数据库',
    '计算机网络',
    '实验',
    '项目开发',
    '考试复习'
  ];

  aboutToAppear(): void {
    if (this.entryDate.length === 0) {
      this.entryDate = this.todayText();
    }
    this.loadHistory(false);
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private todayText(): string {
    const now = new Date();
    return `${now.getFullYear()}-${this.pad2(now.getMonth() + 1)}-${this.pad2(now.getDate())}`;
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private showFormMessage(message: string, success: boolean): void {
    this.formMessage = message;
    this.formMessageSuccess = success;
  }

  private hasTag(tag: string): boolean {
    return this.selectedTags.indexOf(tag) >= 0;
  }

  private toggleTag(tag: string): void {
    if (this.hasTag(tag)) {
      this.selectedTags = this.selectedTags.filter((item: string) => item !== tag);
      return;
    }
    this.selectedTags = [...this.selectedTags, tag];
  }

  private resetForm(): void {
    this.entryDate = this.todayText();
    this.title = '';
    this.moodScore = 8;
    this.content = '';
    this.selectedTags = [];
    this.editingId = 0;
    this.formMessage = '';
    this.customTagInput = '';
    this.showCustomTagInput = false;
  }

  private openCreateForm(): void {
    this.resetForm();
    this.showForm = true;
  }

  private openDetail(entry: DiaryEntry): void {
    this.detailId = entry.id;
    this.detailDate = entry.entryDate;
    this.detailTitle = entry.title;
    this.detailMoodScore = entry.moodScore;
    this.detailTags = [...entry.tags];
    this.detailContent = entry.content;
    this.showDetail = true;
  }

  private fillFormFromDetail(): void {
    this.editingId = this.detailId;
    this.entryDate = this.detailDate;
    this.title = this.detailTitle;
    this.moodScore = this.detailMoodScore;
    this.selectedTags = [...this.detailTags];
    this.content = this.detailContent;
    this.formMessage = '';
    this.showDetail = false;
    this.showForm = true;
  }

  private async doDelete(): Promise<void> {
    if (this.deleting) {
      return;
    }

    const token = this.getToken();
    if (token.length === 0) {
      this.showDetail = false;
      this.historyMessage = '请先登录后再删除日记';
      return;
    }

    this.deleting = true;
    try {
      const result = await deleteStudyDiary(token, this.detailId);
      if (result.success) {
        this.showDetail = false;
        this.historyMessage = '';
        await this.loadHistory(false);
      } else {
        this.historyMessage = result.message || '删除失败';
      }
    } catch (error) {
      this.historyMessage = `删除失败：${(error as Error).message}`;
    } finally {
      this.deleting = false;
    }
  }

  private async loadHistory(isRefresh: boolean): Promise<void> {
    const token = this.getToken();
    if (token.length === 0) {
      this.historyMessage = '请先登录后查看历史日记';
      this.diarySource.setEntries([]);
      this.historyCount = 0;
      this.refreshing = false;
      return;
    }

    if (isRefresh) {
      this.refreshing = true;
    } else {
      this.historyLoading = true;
    }

    try {
      const entries = await fetchDiaryList(token);
      const sortedEntries = entries.sort((left: DiaryEntry, right: DiaryEntry) => {
        return right.entryDate.localeCompare(left.entryDate);
      });
      this.allEntries = sortedEntries;
      this.filterEntries();
      this.historyMessage = '';
    } catch (error) {
      this.historyMessage = `历史日记加载失败：${(error as Error).message}`;
      this.diarySource.setEntries([]);
      this.historyCount = 0;
    } finally {
      this.historyLoading = false;
      this.refreshing = false;
    }
  }

  private async submitDiary(): Promise<void> {
    if (this.loading) {
      return;
    }

    const token = this.getToken();
    if (token.length === 0) {
      this.showFormMessage('请先登录后再保存学习日记', false);
      return;
    }

    if (this.entryDate.trim().length === 0) {
      this.showFormMessage('请选择或填写学习日期', false);
      return;
    }

    if (this.title.trim().length === 0) {
      this.showFormMessage('请填写日记标题', false);
      return;
    }

    if (this.content.trim().length === 0) {
      this.showFormMessage('请填写学习日记内容', false);
      return;
    }

    this.loading = true;
    const isEditing = this.editingId > 0;
    this.showFormMessage(isEditing ? '正在更新学习日记...' : '正在保存学习日记...', true);

    try {
      let result: CommonResult<StudyDiarySaveData>;
      if (isEditing) {
        result = await updateStudyDiary(
          token,
          this.editingId,
          this.entryDate.trim(),
          Math.round(this.moodScore),
          this.title.trim(),
          this.content.trim(),
          this.selectedTags
        );
      } else {
        result = await saveStudyDiary(
          token,
          this.entryDate.trim(),
          Math.round(this.moodScore),
          this.title.trim(),
          this.content.trim(),
          this.selectedTags
        );
      }

      if (result.success) {
        this.showForm = false;
        this.resetForm();
        await this.loadHistory(false);
        return;
      }

      this.showFormMessage(result.message || '操作失败', false);
    } catch (error) {
      this.showFormMessage(`${isEditing ? '更新' : '保存'}失败：${(error as Error).message}`, false);
    } finally {
      this.loading = false;
    }
  }

  private previewContent(content: string): string {
    if (content.length <= 80) {
      return content;
    }
    return `${content.substring(0, 80)}...`;
  }

  private async doPolish(): Promise<void> {
    if (this.polishing) {
      return;
    }

    if (this.content.trim().length === 0) {
      this.showFormMessage('请先输入日记内容后再使用AI润色', false);
      return;
    }

    const token = this.getToken();
    if (token.length === 0) {
      this.showFormMessage('请先登录后再使用AI润色', false);
      return;
    }

    this.polishing = true;
    this.showFormMessage('AI正在润色中...', true);

    try {
      const result = await polishDiary(token, this.content.trim());
      if (result.success && result.data) {
        this.originalContent = this.content;
        this.polishedContent = result.data.result;
        this.showPolishCompare = true;
        this.formMessage = '';
      } else {
        this.showFormMessage(result.message || 'AI润色失败', false);
      }
    } catch (error) {
      this.showFormMessage(`AI润色失败：${(error as Error).message}`, false);
    } finally {
      this.polishing = false;
    }
  }

  private applyPolishedContent(): void {
    this.content = this.polishedContent;
    this.showPolishCompare = false;
    this.showFormMessage('已替换为润色后内容', true);
  }

  private addCustomTag(): void {
    const tag = this.customTagInput.trim();
    if (tag.length === 0) {
      return;
    }
    if (!this.hasTag(tag)) {
      this.selectedTags = [...this.selectedTags, tag];
    }
    this.customTagInput = '';
    this.showCustomTagInput = false;
  }

  private filterEntries(): void {
    const keyword = this.searchKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      this.diarySource.setEntries(this.allEntries);
      this.historyCount = this.allEntries.length;
      return;
    }
    const filtered = this.allEntries.filter((entry: DiaryEntry) => {
      return entry.title.toLowerCase().indexOf(keyword) >= 0;
    });
    this.diarySource.setEntries(filtered);
    this.historyCount = filtered.length;
    this.listVersion++;
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor('#65718E')
      .fontWeight(FontWeight.Medium)
  }

  @Builder
  TagChip(tag: string) {
    Text(tag)
      .height(34)
      .fontSize(13)
      .fontColor(this.hasTag(tag) ? '#FFFFFF' : '#5B6476')
      .padding({ left: 13, right: 13 })
      .borderRadius(17)
      .backgroundColor(this.hasTag(tag) ? '#8B67FF' : '#F3F0FF')
      .border({ width: 1, color: this.hasTag(tag) ? '#8B67FF' : '#E5DEFF' })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.toggleTag(tag);
      })
  }

  @Builder
  HistoryTag(tag: string) {
    Text(tag)
      .fontSize(11)
      .fontColor('#7152D1')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(12)
      .backgroundColor('#F3F0FF')
      .margin({ right: 6, bottom: 6 })
  }

  @Builder
  DiaryHistoryCard(entry: DiaryEntry) {
    Column({ space: 10 }) {
      Row() {
        Text(entry.entryDate)
          .fontSize(13)
          .fontColor('#8A96AD')
          .layoutWeight(1)

        Text(`${entry.moodScore} 分`)
          .fontSize(12)
          .fontColor('#8B67FF')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(13)
          .backgroundColor('#F3F0FF')
      }
      .width('100%')

      Text(entry.title)
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
        .maxLines(1)

      if (entry.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(entry.tags, (tag: string) => {
            this.HistoryTag(tag)
          }, (tag: string) => `${entry.id}-${tag}`)
        }
        .width('100%')
      }

      Text(this.previewContent(entry.content))
        .width('100%')
        .fontSize(14)
        .fontColor('#5B6476')
        .lineHeight(21)
        .maxLines(3)
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
    .onClick(() => {
      this.openDetail(entry);
    })
  }

  @Builder
  EmptyHistory() {
    Column({ space: 8 }) {
      Text('暂无历史日记')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Text('点击右下角 + 开始记录第一篇学习日记')
        .fontSize(13)
        .fontColor('#7B8497')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 30, bottom: 30, left: 16, right: 16 })
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
  }

  @Builder
  HistoryArea() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('历史日记')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          Text(this.historyCount > 0 ? `共 ${this.historyCount} 篇，按日期倒序排列` : '下拉可刷新历史记录')
            .fontSize(12)
            .fontColor('#7B8497')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.historyLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索日记标题...', text: this.searchKeyword })
          .height(40)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor('#0B1B44')
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .border({ width: 1, color: '#EEF2F7' })
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.searchKeyword = value;
            this.filterEntries();
          })

        if (this.searchKeyword.length > 0) {
          Text('✕')
            .fontSize(16)
            .fontColor('#9CA3AF')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .borderRadius(16)
            .backgroundColor('#F3F0FF')
            .onClick(() => {
              this.searchKeyword = '';
              this.filterEntries();
            })
        }
      }
      .width('100%')

      if (this.historyMessage.length > 0) {
        Text(this.historyMessage)
          .width('100%')
          .fontSize(13)
          .fontColor('#DC2626')
          .textAlign(TextAlign.Center)
      }

      if (!this.historyLoading && this.historyCount === 0) {
        this.EmptyHistory()
      } else {
        List({ space: 12 }) {
          LazyForEach(this.diarySource, (entry: DiaryEntry) => {
            ListItem() {
              this.DiaryHistoryCard(entry)
            }
          }, (entry: DiaryEntry) => `${this.listVersion}-${entry.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  DetailPanel() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.detailTitle)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')
            .maxLines(2)

          Row({ space: 8 }) {
            Text(this.detailDate)
              .fontSize(12)
              .fontColor('#8A96AD')

            Text(`${this.detailMoodScore} 分`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#8B67FF')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .backgroundColor('#F3F0FF')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('✕')
          .fontSize(20)
          .fontColor('#9CA3AF')
          .onClick(() => {
            this.showDetail = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })

      Divider()
        .color('#F0F0F5')
        .margin({ left: 20, right: 20 })

      Scroll() {
        Column({ space: 14 }) {
          if (this.detailTags.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.detailTags, (tag: string) => {
                this.HistoryTag(tag)
              }, (tag: string) => `detail-${tag}`)
            }
            .width('100%')
          }

          Column() {
            Text('日记内容')
              .fontSize(12)
              .fontColor('#8A96AD')
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })

            Text(this.detailContent)
              .width('100%')
              .fontSize(15)
              .fontColor('#2D3748')
              .lineHeight(24)
              .maxLines(8)
          }
          .width('100%')
          .padding(14)
          .borderRadius(10)
          .backgroundColor('#F6F8FC')
          .border({ width: 1, color: '#EEF2F7' })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })
      }
      .width('100%')
      .constraintSize({ maxHeight: 260 })
      .scrollBar(BarState.Off)

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Button('编辑')
            .layoutWeight(1)
            .height(44)
            .borderRadius(10)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#8B67FF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.fillFormFromDetail();
            })

          Button('删除')
            .layoutWeight(1)
            .height(44)
            .borderRadius(10)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#FFF1F2')
            .fontColor('#DC2626')
            .border({ width: 1, color: '#FECDD3' })
            .onClick(() => {
              AlertDialog.show({
                title: '确认删除',
                message: '删除后无法恢复，确定要删除这篇日记吗？',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '删除',
                  action: () => {
                    this.doDelete();
                  }
                }
              });
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 18 })
      .backgroundColor('#FFFFFF')
    }
    .width('88%')
    .borderRadius(16)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  PolishComparePanel() {
    Column({ space: 0 }) {
      Row() {
        Text('AI润色对比')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Blank()

        Text('✕')
          .fontSize(20)
          .fontColor('#9CA3AF')
          .onClick(() => {
            this.showPolishCompare = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })

      Divider()
        .color('#F0F0F5')
        .margin({ left: 20, right: 20 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 8 }) {
            Row() {
              Text('原内容')
                .fontSize(13)
                .fontColor('#8A96AD')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')

            Text(this.originalContent)
              .width('100%')
              .fontSize(14)
              .fontColor('#5B6476')
              .lineHeight(22)
          }
          .width('100%')
          .padding(14)
          .borderRadius(10)
          .backgroundColor('#FFF7ED')
          .border({ width: 1, color: '#FED7AA' })

          Column({ space: 8 }) {
            Row() {
              Text('润色后')
                .fontSize(13)
                .fontColor('#8A96AD')
                .fontWeight(FontWeight.Medium)

              Blank()

              Text('AI生成')
                .fontSize(11)
                .fontColor('#7152D1')
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(10)
                .backgroundColor('#F3F0FF')
            }
            .width('100%')

            Text(this.polishedContent)
              .width('100%')
              .fontSize(14)
              .fontColor('#2D3748')
              .lineHeight(22)
          }
          .width('100%')
          .padding(14)
          .borderRadius(10)
          .backgroundColor('#F0FDF4')
          .border({ width: 1, color: '#BBF7D0' })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Button('替换内容')
            .layoutWeight(1)
            .height(44)
            .borderRadius(10)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#8B67FF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.applyPolishedContent();
            })

          Button('取消')
            .layoutWeight(1)
            .height(44)
            .borderRadius(10)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#F3F0FF')
            .fontColor('#7152D1')
            .onClick(() => {
              this.showPolishCompare = false;
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 18 })
      .backgroundColor('#FFFFFF')
    }
    .width('88%')
    .borderRadius(16)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  FormPanel() {
    Column({ space: 16 }) {
      Row() {
        Text(this.editingId > 0 ? '编辑学习日记' : '学习日记录入')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Blank()

        if (this.editingId > 0) {
          Button('取消编辑')
            .height(30)
            .fontSize(12)
            .fontColor('#8B67FF')
            .backgroundColor('#F3F0FF')
            .borderRadius(15)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.resetForm();
            })
        }
      }
      .width('100%')

      Text(this.editingId > 0 ? '修改后点击保存按钮完成更新' : '记录今天的学习状态、主题和收获')
        .width('100%')
        .fontSize(12)
        .fontColor('#7B8497')
        .margin({ top: -8 })

      Column({ space: 8 }) {
        this.FieldLabel('日期')
        TextInput({ placeholder: 'YYYY-MM-DD', text: this.entryDate })
          .height(46)
          .fontSize(16)
          .fontColor('#0B1B44')
          .backgroundColor('#F6F8FC')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.entryDate = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        this.FieldLabel('日记标题')
        TextInput({ placeholder: '例如：数据库实验', text: this.title })
          .height(46)
          .fontSize(16)
          .fontColor('#0B1B44')
          .backgroundColor('#F6F8FC')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.title = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Row() {
          this.FieldLabel('今日学习心情')
          Blank()
          Text(`${Math.round(this.moodScore)} 分`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#8B67FF')
        }
        .width('100%')

        Slider({
          value: this.moodScore,
          min: 1,
          max: 10,
          step: 1
        })
          .width('100%')
          .selectedColor('#8B67FF')
          .trackColor('#E6EAF2')
          .blockColor('#FFFFFF')
          .showTips(true)
          .onChange((value: number) => {
            this.moodScore = value;
          })

        Row() {
          Text('1')
            .fontSize(12)
            .fontColor('#9CA3AF')
          Blank()
          Text('10')
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        this.FieldLabel('标签选择')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tagOptions, (tag: string) => {
            this.TagChip(tag)
          }, (tag: string) => tag)

          Text('+')
            .height(34)
            .width(34)
            .fontSize(18)
            .fontColor('#8B67FF')
            .textAlign(TextAlign.Center)
            .borderRadius(17)
            .backgroundColor('#F3F0FF')
            .border({ width: 1, color: '#E5DEFF' })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.showCustomTagInput = !this.showCustomTagInput;
              this.customTagInput = '';
            })
        }
        .width('100%')

        if (this.showCustomTagInput) {
          Row({ space: 8 }) {
            TextInput({ placeholder: '输入自定义标签', text: this.customTagInput })
              .height(36)
              .layoutWeight(1)
              .fontSize(14)
              .fontColor('#0B1B44')
              .backgroundColor('#F6F8FC')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.customTagInput = value;
              })
              .onSubmit(() => {
                this.addCustomTag();
              })

            Button('添加')
              .height(36)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#8B67FF')
              .borderRadius(8)
              .padding({ left: 14, right: 14 })
              .onClick(() => {
                this.addCustomTag();
              })
          }
          .width('100%')
        }

        if (this.selectedTags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.selectedTags, (tag: string) => {
              Row({ space: 4 }) {
                Text(tag)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                Text('✕')
                  .fontSize(10)
                  .fontColor('#FFFFFF')
                  .opacity(0.8)
              }
              .height(28)
              .padding({ left: 10, right: 8 })
              .borderRadius(14)
              .backgroundColor('#8B67FF')
              .margin({ right: 6, bottom: 6 })
              .onClick(() => {
                this.toggleTag(tag);
              })
            }, (tag: string) => `selected-${tag}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        this.FieldLabel('学习日记内容')
        TextArea({ placeholder: '写下今天学了什么、遇到了什么问题、下一步准备怎么做', text: this.content })
          .height(120)
          .fontSize(15)
          .fontColor('#0B1B44')
          .lineHeight(22)
          .backgroundColor('#F6F8FC')
          .borderRadius(8)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.content = value;
          })

        Row() {
          Button() {
            Row({ space: 6 }) {
              Text('✨')
                .fontSize(14)
              Text(this.polishing ? '润色中...' : 'AI润色')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
            }
          }
          .height(32)
          .borderRadius(16)
          .backgroundColor(this.polishing ? '#D4C8FF' : '#F3F0FF')
          .fontColor('#7152D1')
          .padding({ left: 14, right: 14 })
          .enabled(!this.polishing)
          .onClick(() => {
            this.doPolish();
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.formMessage.length > 0) {
        Text(this.formMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(this.formMessageSuccess ? '#047857' : '#DC2626')
          .textAlign(TextAlign.Center)
      }

      Row({ space: 12 }) {
        Button(this.loading ?
          (this.editingId > 0 ? '更新中...' : '保存中...') :
          (this.editingId > 0 ? '更新学习日记' : '保存学习日记'))
          .layoutWeight(1)
          .height(44)
          .borderRadius(8)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#8B67FF')
          .fontColor('#FFFFFF')
          .enabled(!this.loading)
          .onClick(() => {
            this.submitDiary();
          })

        Button('取消')
          .width(80)
          .height(44)
          .borderRadius(8)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#F3F0FF')
          .fontColor('#8B67FF')
          .onClick(() => {
            this.showForm = false;
          })
      }
      .width('100%')
    }
    .width('88%')
    .padding(20)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        FeaturePageHeader({
          title: '学习日记',
          themeColor: '#8B67FF'
        })

        Stack({ alignContent: Alignment.BottomEnd }) {
          Refresh({ refreshing: $$this.refreshing }) {
            Column({ space: 16 }) {
              this.HistoryArea()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 18 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#F6F8FC')
          .onRefreshing(() => {
            this.loadHistory(true);
          })

          Button() {
            Text('+')
              .fontSize(28)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor('#8B67FF')
          .shadow({
            radius: 12,
            color: '#338B67FF',
            offsetX: 0,
            offsetY: 4
          })
          .margin({ right: 20, bottom: 20 })
          .onClick(() => {
            this.openCreateForm();
          })
        }
        .width('100%')
        .layoutWeight(1)

        FeatureBottomNav({
          selectedIndex: 3
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F8FC')

      if (this.showDetail) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.showDetail = false;
          })

        this.DetailPanel()
      }

      if (this.showForm) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.showForm = false;
          })

        Scroll() {
          this.FormPanel()
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }

      if (this.showPolishCompare) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.showPolishCompare = false;
          })

        this.PolishComparePanel()
      }
    }
    .width('100%')
    .height('100%')
  }
}
