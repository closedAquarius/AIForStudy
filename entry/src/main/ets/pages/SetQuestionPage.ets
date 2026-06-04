import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct SetQuestionPage {
  build() {
    Column() {
      FeaturePageHeader({
        title: '文档出题',
        themeColor: '#38C98A'
      })

      Column() {
        // 后续在这里开发文档上传、AI 出题页面内容
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}