import { FeaturePageHeader } from '../components/FeaturePageHeader';
import { FeatureBottomNav } from '../components/FeatureBottomNav';

@Entry
@Component
struct PracticePage {
  build() {
    Column() {
      FeaturePageHeader({
        title: '题库刷题',
        themeColor: '#2D75FF'
      })

      Column() {
        // 后续在这里开发题库刷题页面内容
      }
      .width('100%')
      .layoutWeight(1)

      FeatureBottomNav({
        selectedIndex: 1
      })
    }
    .width('100%')
    .height('100%')
  }
}