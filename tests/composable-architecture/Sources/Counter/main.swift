import ComposableArchitecture

/// The smallest reducer that needs the library's macros.
@Reducer struct Counter {
  @ObservableState struct State: Equatable { var count = 0 }
  enum Action { case increment }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}

@MainActor func run() {
  let store = Store(initialState: Counter.State()) { Counter() }
  store.send(.increment)
  print("count", store.count)
}

run()
