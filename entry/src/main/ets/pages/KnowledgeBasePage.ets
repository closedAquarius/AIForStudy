import { fileIo, picker } from '@kit.CoreFileKit';
import { router } from '@kit.ArkUI';
import {
  KnowledgeBaseItem,
  KnowledgeDocumentItem,
  KnowledgeQueryItem,
  KnowledgeSourceItem,
  askKnowledgeBase,
  createKnowledgeBase,
  deleteKnowledgeBase,
  getKnowledgeBases,
  getKnowledgeDocuments,
  getKnowledgeQueries,
  removeKnowledgeDocument,
  uploadKnowledgeDocument
} from '../common/ApiClient';

@Entry
@Component
struct KnowledgeBasePage {
  @State bases: KnowledgeBaseItem[] = [];
  @State documents: KnowledgeDocumentItem[] = [];
  @State queries: KnowledgeQueryItem[] = [];
  @State selectedBaseId: number = 0;
  @State selectedBaseName: string = '文档知识库';
  @State question: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  @State asking: boolean = false;
  @State uploading: boolean = false;
  @State showCreateDialog: boolean = false;
  @State showDocuments: boolean = false;
  @State newBaseName: string = '';
  @State newBaseDescription: string = '';
  @State expandedSourceQueryId: number = 0;

  aboutToAppear(): void {
    this.loadBases();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private async loadBases(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const result = await getKnowledgeBases(this.getToken());
      if (result.success && result.data) {
        this.bases = result.data.knowledgeBases;
        if (this.bases.length > 0) {
          let selected = this.bases[0];
          for (let i = 0; i < this.bases.length; i++) {
            if (this.bases[i].id === this.selectedBaseId) {
              selected = this.bases[i];
            }
          }
          await this.selectBase(selected);
        } else {
          this.selectedBaseId = 0;
          this.selectedBaseName = '文档知识库';
          this.documents = [];
          this.queries = [];
        }
      } else {
        this.message = result.message || '知识库加载失败';
      }
    } catch (error) {
      this.message = `知识库加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private async selectBase(base: KnowledgeBaseItem): Promise<void> {
    this.selectedBaseId = base.id;
    this.selectedBaseName = base.name;
    this.message = '';
    await Promise.all([this.loadDocuments(), this.loadQueries()]);
  }

  private async loadDocuments(): Promise<void> {
    if (this.selectedBaseId <= 0) {
      this.documents = [];
      return;
    }
    const result = await getKnowledgeDocuments(this.getToken(), this.selectedBaseId);
    if (result.success && result.data) {
      this.documents = result.data.documents;
    } else {
      this.message = result.message || '知识库文档加载失败';
    }
  }

  private async loadQueries(): Promise<void> {
    if (this.selectedBaseId <= 0) {
      this.queries = [];
      return;
    }
    const result = await getKnowledgeQueries(this.getToken(), this.selectedBaseId, 50);
    if (result.success && result.data) {
      this.queries = result.data.queries;
    } else {
      this.message = result.message || '问答记录加载失败';
    }
  }

  private async createBase(): Promise<void> {
    const name = this.newBaseName.trim();
    if (name.length === 0) {
      this.message = '请输入知识库名称';
      return;
    }
    try {
      const result = await createKnowledgeBase(
        this.getToken(),
        name,
        this.newBaseDescription.trim()
      );
      if (result.success && result.data) {
        this.showCreateDialog = false;
        this.newBaseName = '';
        this.newBaseDescription = '';
        this.selectedBaseId = result.data.id;
        await this.loadBases();
      } else {
        this.message = result.message || '知识库创建失败';
      }
    } catch (error) {
      this.message = `知识库创建失败：${(error as Error).message}`;
    }
  }

  private async removeCurrentBase(): Promise<void> {
    if (this.selectedBaseId <= 0) {
      return;
    }
    const result = await deleteKnowledgeBase(this.getToken(), this.selectedBaseId);
    if (result.success) {
      this.showDocuments = false;
      this.selectedBaseId = 0;
      await this.loadBases();
    } else {
      this.message = result.message || '知识库删除失败';
    }
  }

  private async selectDocument(): Promise<void> {
    if (this.selectedBaseId <= 0 || this.uploading) {
      this.message = '请先创建或选择知识库';
      return;
    }
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['.docx', '.pptx', '.pdf', '.txt'];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select(options);
      if (result.length === 0) {
        return;
      }
      const uri = result[0];
      const parts = uri.split('/');
      const rawName = parts.length > 0 ? parts[parts.length - 1] : uri;
      const fileName = decodeURIComponent(rawName);
      const cachePath = this.copyToCache(uri, fileName);
      this.uploading = true;
      this.message = '正在上传并解析文档...';
      const uploadResult = await uploadKnowledgeDocument(
        this.getToken(),
        this.selectedBaseId,
        cachePath,
        fileName
      );
      if (uploadResult.success) {
        this.message = '文档已加入知识库';
        await this.loadDocuments();
        await this.loadBases();
      } else {
        this.message = uploadResult.message || '文档上传失败';
      }
    } catch (error) {
      this.message = `文档上传失败：${(error as Error).message}`;
    } finally {
      this.uploading = false;
    }
  }

  private async removeDocument(documentId: number): Promise<void> {
    const result = await removeKnowledgeDocument(
      this.getToken(),
      this.selectedBaseId,
      documentId
    );
    if (result.success) {
      this.message = '文档已移出知识库';
      await this.loadDocuments();
      await this.loadBases();
    } else {
      this.message = result.message || '文档删除失败';
    }
  }

  private async submitQuestion(): Promise<void> {
    const text = this.question.trim();
    if (this.asking || text.length === 0) {
      return;
    }
    if (this.selectedBaseId <= 0) {
      this.message = '请先创建或选择知识库';
      return;
    }
    if (this.documents.length === 0) {
      this.message = '请先上传课程文档';
      return;
    }
    this.asking = true;
    this.message = '';
    try {
      const result = await askKnowledgeBase(this.getToken(), this.selectedBaseId, text);
      if (result.success && result.data) {
        const item: KnowledgeQueryItem = {
          id: result.data.queryId,
          question: text,
          answer: result.data.answer,
          sources: result.data.sources,
          createdAt: ''
        };
        this.queries = [...this.queries, item];
        this.question = '';
      } else {
        this.message = result.message || '回答生成失败';
      }
    } catch (error) {
      this.message = `回答生成失败：${(error as Error).message}`;
    } finally {
      this.asking = false;
    }
  }

  private copyToCache(sourceUri: string, fileName: string): string {
    const cacheFileName = `knowledge-${new Date().getTime()}${this.fileSuffix(fileName)}`;
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
    return index >= 0 ? fileName.substring(index) : '';
  }

  @Builder
  BaseTabs() {
    List({ space: 8 }) {
      ForEach(this.bases, (base: KnowledgeBaseItem) => {
        ListItem() {
          Button(base.name)
            .height(36)
            .fontSize(13)
            .fontColor(this.selectedBaseId === base.id ? '#FFFFFF' : '#334155')
            .backgroundColor(this.selectedBaseId === base.id ? '#2563EB' : '#F1F5F9')
            .borderRadius(8)
            .onClick(() => {
              this.selectBase(base);
            })
        }
      }, (base: KnowledgeBaseItem) => base.id.toString())

      ListItem() {
        Button('+')
          .width(42)
          .height(36)
          .fontSize(22)
          .fontColor('#2563EB')
          .backgroundColor('#EEF5FF')
          .borderRadius(8)
          .onClick(() => {
            this.showCreateDialog = true;
          })
      }
    }
    .width('100%')
    .height(48)
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  SourceList(query: KnowledgeQueryItem) {
    Column({ space: 8 }) {
      ForEach(query.sources, (source: KnowledgeSourceItem, index: number) => {
        Column({ space: 4 }) {
          Text(`来源 ${index + 1} · ${source.fileName} · ${source.pageLabel}`)
            .width('100%')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2563EB')
          Text(source.content)
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor('#475569')
            .maxLines(6)
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#F8FAFC')
        .borderRadius(8)
      }, (source: KnowledgeSourceItem, index: number) => `${source.documentId}-${source.chunkIndex}-${index}`)
    }
    .width('100%')
  }

  @Builder
  QueryCard(query: KnowledgeQueryItem) {
    Column({ space: 10 }) {
      Row() {
        Blank().layoutWeight(1)
        Text(query.question)
          .constraintSize({ maxWidth: '82%' })
          .fontSize(14)
          .lineHeight(21)
          .fontColor('#FFFFFF')
          .padding(12)
          .backgroundColor('#2563EB')
          .borderRadius(8)
      }
      .width('100%')

      Column({ space: 8 }) {
        Text(query.answer)
          .width('100%')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#1E293B')

        if (query.sources.length > 0) {
          Button(this.expandedSourceQueryId === query.id ? '收起资料来源' : `查看 ${query.sources.length} 个资料来源`)
            .height(32)
            .fontSize(11)
            .fontColor('#2563EB')
            .backgroundColor('#EEF5FF')
            .borderRadius(8)
            .onClick(() => {
              this.expandedSourceQueryId = this.expandedSourceQueryId === query.id ? 0 : query.id;
            })
        }

        if (this.expandedSourceQueryId === query.id) {
          this.SourceList(query)
        }
      }
      .width('92%')
      .alignSelf(ItemAlign.Start)
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .border({ width: 1, color: '#E5EAF3' })
    }
    .width('100%')
  }

  @Builder
  EmptyArea() {
    Column({ space: 10 }) {
      Text(this.selectedBaseId <= 0 ? '创建你的第一个知识库' : '上传课程文档后开始提问')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
      Text(this.selectedBaseId <= 0
        ? '可以按课程或专题分别管理学习资料'
        : '支持 PPTX、DOCX、PDF 和 TXT')
        .fontSize(13)
        .fontColor('#64748B')
      Button(this.selectedBaseId <= 0 ? '新建知识库' : '上传文档')
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#2563EB')
        .borderRadius(8)
        .onClick(() => {
          if (this.selectedBaseId <= 0) {
            this.showCreateDialog = true;
          } else {
            this.selectDocument();
          }
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  DocumentPanel() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.selectedBaseName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')
          Text(`${this.documents.length} 份文档`)
            .fontSize(12)
            .fontColor('#64748B')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button('关闭')
          .height(34)
          .fontSize(12)
          .fontColor('#475569')
          .backgroundColor('#F1F5F9')
          .borderRadius(8)
          .onClick(() => {
            this.showDocuments = false;
          })
      }
      .width('100%')

      Button(this.uploading ? '解析中...' : '+ 上传文档')
        .width('100%')
        .height(42)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#2563EB')
        .borderRadius(8)
        .enabled(!this.uploading)
        .onClick(() => {
          this.selectDocument();
        })

      if (this.documents.length === 0) {
        Text('暂无文档')
          .width('100%')
          .fontSize(13)
          .fontColor('#94A3B8')
          .textAlign(TextAlign.Center)
          .padding({ top: 24 })
      } else {
        List({ space: 8 }) {
          ForEach(this.documents, (document: KnowledgeDocumentItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(document.fileName)
                    .width('100%')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#0B1B44')
                    .maxLines(2)
                  Text(`${document.fileType.toUpperCase()} · ${document.chunkCount} 个片段`)
                    .fontSize(11)
                    .fontColor('#64748B')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('删除')
                  .height(32)
                  .fontSize(11)
                  .fontColor('#DC2626')
                  .backgroundColor('#FFF1F2')
                  .borderRadius(8)
                  .onClick(() => {
                    this.removeDocument(document.id);
                  })
              }
              .width('100%')
              .padding(11)
              .backgroundColor('#F8FAFC')
              .borderRadius(8)
            }
          }, (document: KnowledgeDocumentItem) => document.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      Button('删除当前知识库')
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor('#DC2626')
        .backgroundColor('#FFF1F2')
        .borderRadius(8)
        .onClick(() => {
          this.removeCurrentBase();
        })
    }
    .width('86%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 18 })
    .backgroundColor('#FFFFFF')
    .alignSelf(ItemAlign.End)
  }

  @Builder
  CreateDialog() {
    Column({ space: 14 }) {
      Text('新建知识库')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      TextInput({ placeholder: '例如：软件项目管理', text: this.newBaseName })
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#F3F5F8')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.newBaseName = value;
        })

      TextArea({ placeholder: '简单描述这个知识库的用途', text: this.newBaseDescription })
        .width('100%')
        .height(90)
        .fontSize(14)
        .backgroundColor('#F3F5F8')
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => {
          this.newBaseDescription = value;
        })

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontColor('#475569')
          .backgroundColor('#F1F5F9')
          .borderRadius(8)
          .onClick(() => {
            this.showCreateDialog = false;
          })
        Button('创建')
          .layoutWeight(1)
          .height(42)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .borderRadius(8)
          .onClick(() => {
            this.createBase();
          })
      }
      .width('100%')
    }
    .width('88%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Button('<')
            .width(40)
            .height(40)
            .fontSize(22)
            .fontColor('#2563EB')
            .backgroundColor('#EEF5FF')
            .borderRadius(20)
            .onClick(() => {
              router.back();
            })
          Column({ space: 2 }) {
            Text(this.selectedBaseName)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0B1B44')
            Text('基于课程文档回答并标注来源')
              .fontSize(11)
              .fontColor('#64748B')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          Button('资料')
            .width(56)
            .height(38)
            .fontSize(12)
            .fontColor('#2563EB')
            .backgroundColor('#EEF5FF')
            .borderRadius(8)
            .enabled(this.selectedBaseId > 0)
            .onClick(() => {
              this.showDocuments = true;
            })
        }
        .width('100%')
        .height(66)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#FFFFFF')

        this.BaseTabs()

        if (this.message.length > 0) {
          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor(this.message.includes('失败') ? '#DC2626' : '#475569')
            .textAlign(TextAlign.Center)
            .padding({ top: 6, bottom: 6 })
            .backgroundColor('#F8FAFC')
        }

        if (this.selectedBaseId <= 0 || (this.documents.length === 0 && this.queries.length === 0)) {
          this.EmptyArea()
        } else {
          List({ space: 16 }) {
            ForEach(this.queries, (query: KnowledgeQueryItem) => {
              ListItem() {
                this.QueryCard(query)
              }
            }, (query: KnowledgeQueryItem) => query.id.toString())

            if (this.asking) {
              ListItem() {
                Row({ space: 8 }) {
                  LoadingProgress().width(20).height(20)
                  Text('正在检索资料并生成回答...')
                    .fontSize(13)
                    .fontColor('#64748B')
                }
                .width('92%')
                .padding(14)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 14, right: 14, top: 14, bottom: 12 })
          .backgroundColor('#F5F7FB')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }

        Row({ space: 8 }) {
          TextArea({ placeholder: '向知识库提问...', text: this.question })
            .layoutWeight(1)
            .height(52)
            .fontSize(14)
            .backgroundColor('#F3F5F8')
            .borderRadius(8)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onChange((value: string) => {
              this.question = value;
            })
          Button('发送')
            .width(62)
            .height(52)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor(this.question.trim().length > 0 && !this.asking ? '#2563EB' : '#94A3B8')
            .borderRadius(8)
            .enabled(this.question.trim().length > 0 && !this.asking)
            .onClick(() => {
              this.submitQuestion();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 12 })
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')

      if (this.showDocuments) {
        Row() {
          Blank().layoutWeight(1)
          this.DocumentPanel()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
      }

      if (this.showCreateDialog) {
        Column() {
          this.CreateDialog()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#66000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}
