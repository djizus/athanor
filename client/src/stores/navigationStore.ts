import { create } from 'zustand'

export type PageId = 'home' | 'play' | 'mygames' | 'leaderboard'

type NavigationState = {
  currentPage: PageId
  gameId: number | null
  navigate: (page: PageId, gameId?: number) => void
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

    if (currentPage === 'play' || currentPage === 'mygames' || currentPage === 'leaderboard') {
      set({ currentPage: 'home', gameId: null })
    }
  },
}))
