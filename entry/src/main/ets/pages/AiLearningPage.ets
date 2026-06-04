import { FeaturePageHeader } from '../components/FeaturePageHeader';

@Entry
@Component
struct AiLearningPage {
  build() {
    Column() {
      FeaturePageHeader({
        title: 'AI辅学',
        themeColor: '#FFAA45'
      })

      Column() {
        // 后续在这里开发 AI 问答、错题讲解、学习计划页面内容
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}