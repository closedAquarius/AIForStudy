import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct DiaryPage {
  build() {
    Column() {
      FeaturePageHeader({
        title: '学习日记',
        themeColor: '#8B67FF'
      })

      Column() {
        // 后续在这里开发学习日记页面内容
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}