import { create } from 'zustand'

export type PageId = 'home' | 'play' | 'mygames' | 'leaderboard' | 'howtoplay'

type NavigationState = {
  currentPage: PageId
  gameId: bigint | null
  navigate: (page: PageId, gameId?: bigint) => void
  goBack: () => void
}

export const useNavigationStore = create<NavigationState>((set, get) => ({
  currentPage: 'home',
  gameId: null,
  navigate: (page, gameId) => {
    set({
      currentPage: page,
      gameId: gameId ?? (page === 'play' ? get().gameId : null),
    })
  },
  goBack: () => {
    const { currentPage } = get()

    if (currentPage === 'play' || currentPage === 'mygames' || currentPage === 'leaderboard' || currentPage === 'howtoplay') {
      set({ currentPage: 'home', gameId: null })
    }
  },
}))
