export interface AppTheme {
  id: string;
  name: string;
  description: string;
  pageBackground: string;
  surfaceBackground: string;
  secondarySurface: string;
  cardBackground: string;
  softBackground: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentSoft: string;
  accentContrast: string;
  border: string;
  success: string;
  successSoft: string;
  warning: string;
  warningSoft: string;
  danger: string;
  dangerSoft: string;
  shadow: string;
}

export const DEFAULT_THEME_ID: string = 'summer';

export const APP_THEMES: AppTheme[] = [
  {
    id: 'night',
    name: '黑夜模式',
    description: '沉静深色，适合晚间专注',
    pageBackground: '#0E1424',
    surfaceBackground: '#151E33',
    secondarySurface: '#1B2742',
    cardBackground: '#1A2640',
    softBackground: '#243352',
    textPrimary: '#F8FAFC',
    textSecondary: '#CBD5E1',
    textMuted: '#94A3B8',
    accent: '#7DD3FC',
    accentSoft: '#173A52',
    accentContrast: '#0B1B2F',
    border: '#2C3B5B',
    success: '#4ADE80',
    successSoft: '#163522',
    warning: '#FBBF24',
    warningSoft: '#4A360A',
    danger: '#FB7185',
    dangerSoft: '#4A1F2D',
    shadow: '#44000000'
  },
  {
    id: 'eye',
    name: '护眼模式',
    description: '柔和绿调，减轻视觉疲劳',
    pageBackground: '#EEF5E9',
    surfaceBackground: '#F8FBF4',
    secondarySurface: '#E6F0DD',
    cardBackground: '#FCFEFA',
    softBackground: '#DFECD1',
    textPrimary: '#243425',
    textSecondary: '#4D6450',
    textMuted: '#6F8571',
    accent: '#5A8F4C',
    accentSoft: '#DDEBCC',
    accentContrast: '#F8FBF4',
    border: '#C9D9BF',
    success: '#4F9D69',
    successSoft: '#D7ECDD',
    warning: '#B68A3F',
    warningSoft: '#F0E5CC',
    danger: '#C96A55',
    dangerSoft: '#F5DED7',
    shadow: '#1A335522'
  },
  {
    id: 'summer',
    name: '夏日清爽',
    description: '清亮蓝绿，轻快通透',
    pageBackground: '#F4F9FF',
    surfaceBackground: '#FFFFFF',
    secondarySurface: '#EEF7FF',
    cardBackground: '#FFFFFF',
    softBackground: '#E8F4FF',
    textPrimary: '#102A43',
    textSecondary: '#486581',
    textMuted: '#7B8794',
    accent: '#2D75FF',
    accentSoft: '#E8F1FF',
    accentContrast: '#FFFFFF',
    border: '#D9E8F7',
    success: '#16A66A',
    successSoft: '#E8F8F0',
    warning: '#F59E0B',
    warningSoft: '#FFF4DA',
    danger: '#E05252',
    dangerSoft: '#FFF1F2',
    shadow: '#1A2D75FF'
  },
  {
    id: 'winter',
    name: '冬日暖阳',
    description: '米杏暖调，安静柔和',
    pageBackground: '#FFF8EF',
    surfaceBackground: '#FFFCF6',
    secondarySurface: '#FFF2DE',
    cardBackground: '#FFFFFF',
    softBackground: '#FFF1E0',
    textPrimary: '#4A3728',
    textSecondary: '#7A5C45',
    textMuted: '#9B7E69',
    accent: '#E08A2E',
    accentSoft: '#FFF0DB',
    accentContrast: '#FFFDF9',
    border: '#F2DEC5',
    success: '#4D9A78',
    successSoft: '#E3F1EA',
    warning: '#D97706',
    warningSoft: '#FFF1D9',
    danger: '#D3634C',
    dangerSoft: '#FBE5DF',
    shadow: '#1A9A5B1A'
  }
];

export function ensureThemeStorage(): void {
  AppStorage.SetOrCreate<string>('appThemeId', AppStorage.Get<string>('appThemeId') ?? DEFAULT_THEME_ID);
}

export function getAppTheme(themeId?: string): AppTheme {
  const currentId = themeId ?? AppStorage.Get<string>('appThemeId') ?? DEFAULT_THEME_ID;
  const match = APP_THEMES.find((item: AppTheme) => item.id === currentId);
  return match ?? APP_THEMES[2];
}

export function updateAppTheme(themeId: string): AppTheme {
  const theme = getAppTheme(themeId);
  AppStorage.SetOrCreate<string>('appThemeId', theme.id);
  return theme;
}
