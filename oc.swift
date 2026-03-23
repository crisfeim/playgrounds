
// p12-tally-goals.swift

// TallyGoals/App/Architecture/Actions.swift
//
//  Actions.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import ComposableArchitecture
import CoreData

/// The AppAction enum models the actions of the app
/// This actions are send to the store by using the send method which take an action as argument
/// Actions are handle by the reducer
enum AppAction: Equatable {

  // MARK: - CRUD Behaviours
  case createBehaviour(
    id: UUID,
    emoji: String,
    name: String
  )
  
  case readBehaviours
  case makeBehaviourState(_ state: BehaviourState)
  
  case updateBehaviour(
    id: UUID,
    emoji: String,
    name: String
  )
  
  case updateFavorite(id: UUID, favorite: Bool)
  case updateArchive(id: UUID, archive: Bool)
  case updatePinned(id: UUID, pinned: Bool)
  
  case deleteBehaviour(id: UUID)
  
  // MARK: CRUD Entries
  case addEntry(behaviour: UUID)
  case deleteEntry(behaviour: UUID)
  
  case setOverlay(overlay: Overlay?)
}


// TallyGoals/App/Architecture/Aliases.swift
//
//  Aliases.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import ComposableArchitecture

/// As described by pointfree.co:
/// _A store represents the runtime that powers the application. It is the object that you will pass around to views that need to interact with the application._
/// AppStore is a typealias to make code cleaner when passing store across views
typealias AppStore = Store<AppState, AppAction>

/// View store is an observable version of the store. Whenever the store changes,
/// views "listening" to the viewStore will be updated if needed
/// AppViewStore is a typealias to make code cleaner when passing viewStore across views
typealias AppViewStore = ViewStore<AppState, AppAction>

/// Whenever  an action is send to the store,
/// the app reducer handles it
typealias AppReducer = Reducer<AppState, AppAction, AppEnvironment>


// TallyGoals/App/Architecture/Environment.swift
//
//  Environment.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import ComposableArchitecture

/// The environment is the depenciens handler
/// here we declare all the needed dependencies
struct AppEnvironment {
  let behavioursRepository: BehaviourRepository
}

extension AppEnvironment {
  static var instance: AppEnvironment {
    .init(
      behavioursRepository: container.behaviourRepository
    )
  }
}


// TallyGoals/App/Architecture/Reducer.swift
import ComposableArchitecture
import CoreData

/// Whenever  an action is send to the store,
/// the app reducer handles it
let appReducer = AppReducer { state, action, env in
  
  switch action {
   
  case .createBehaviour(let id, let emoji, let name):
    return env.behavioursRepository
      .createBehaviour(id: id, emoji: emoji, name: name)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
  case .readBehaviours:
    state.behaviourState = .loading
    return env.behavioursRepository
    .fetchBehaviours()
    .catchToEffect()
    .map { result in
      var behaviourState: BehaviourState = .idle
      switch result {
      case .success(let behaviours):
        if behaviours.count > 0 {
        behaviourState = .success(behaviours)
        } else {
          behaviourState = .empty
        }
      case .failure(let error):
        behaviourState = .error(error.localizedDescription)
      }
      return .makeBehaviourState(behaviourState)
    }

  case .makeBehaviourState(let behaviourState):
    state.behaviourState = behaviourState
    return .none
    
  case .updateFavorite(let id, let favorite):
    return env.behavioursRepository
      .updateFavorite(id: id, favorite: favorite)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
    
  case .updateArchive(let id, let archived):
    return env.behavioursRepository
      .updateArchived(id: id, archived: archived)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
    
  case .updatePinned(let id, let pinned):
    return env.behavioursRepository
      .updatePinned(id: id, pinned: pinned)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
    
  case .updateBehaviour(let id, let emoji, let name):
    return env.behavioursRepository
      .updateBehaviour(id: id, emoji: emoji, name: name)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
    
  case .deleteBehaviour(let id):
    return env.behavioursRepository
      .deleteBehaviour(id: id)
      .catchToEffect()
      .map { _ in AppAction.readBehaviours }
    
    
  case .deleteEntry(let id):
    return env.behavioursRepository
    .deleteLastEntry(for: id)
    .catchToEffect()
    .map { _ in AppAction.readBehaviours }
  
    
  case .addEntry(let behaviourId):
    return env.behavioursRepository
    .createEntity(for: behaviourId)
    .catchToEffect()
    .map { _ in AppAction.readBehaviours }
  
    
  case .setOverlay(let overlay):
    state.overlay = overlay
    return .none
  }
}


// TallyGoals/App/Architecture/State.swift
//
//  State.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//
import ComposableArchitecture
import CoreData
import SwiftUI


/// The AppState is responsible to holds the states of the app
/// that are needed in all views.
/// This allows a view to be automatically be reloaded as a side-effect of an action in other view
/// which allows for cleaner code (don't need to reload through callbacks/notifications/delegates...)
struct AppState: Equatable {
 
  var behaviourState: BehaviourState = .idle
  var overlay: Overlay?
}



// TallyGoals/App/Tabbar.swift
import ComposableArchitecture
import SwiftUI
import SwiftUItilities
import SwiftWind

struct Tabbar: View {
  
  let store: Store<AppState, AppAction>
  @State var selection: Int = 0
  var body: some View {
    
    WithViewStore(store) { viewStore in
      
      TabView(selection: $selection) {
        
        
        HomeScreen(store: store)
          .navigationTitle("Compteurs")
          .navigationify()
          .navigationViewStyle(.stack)
          .tag(0)
          .tabItem {
            Label("Compteurs", systemImage: "house")
          }
        
        ExploreScreen(viewStore: viewStore)
          .navigationTitle("Découvrir")
          .navigationify()
          .navigationViewStyle(.stack)
          .tag(1)
          .tabItem {
            Label("Découvrir", systemImage: "plus.rectangle.fill")
          }
        
        ArchivedScreen(store: store)
          .navigationTitle("Archive")
          .navigationify()
          .navigationViewStyle(.stack)
          .tag(2)
          .tabItem {
            Label("Archive", systemImage: "archivebox")
          }
      }
      .overlay(overlay(viewStore: viewStore))
    }
  }
  
  @ViewBuilder
  func overlay(viewStore: AppViewStore) -> some View {
    switch viewStore.state.overlay {
    case .exploreDetail(let category):
      PresetCategoryDetailScreen(model: category, viewStore: viewStore)
    case .error(let title, let message):
      ErrorView(title: title, message: message, viewStore: viewStore)
    case .none:
      EmptyView()
    }
  }
}


// TallyGoals/App/TallyGoalsApp.swift
//
//  TallyGoalsApp.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 27/05/2022.
//

import ComposableArchitecture
import SwiftUI


/// Entry point of the application
@main
struct TallyGoalsApp: App {
  
  @AppStorage("showOnboarding") var showOnboarding: Bool = true
  
  init() {
    UIBarButtonItem.hideBackButtonLabel()
    UINavigationBar.setupFonts()
  }
  
  var body: some Scene {
    WindowGroup {
      
      if showOnboarding {
        OnboardingScreen(store: container.store)
      } else {
        Tabbar(store: container.store)
      }
    }
  }
}


// TallyGoals/Data/BehaviourRepository.swift
import Combine
import ComposableArchitecture
import CoreData
import AVFAudio

final class BehaviourRepository {
  
  private let context: NSManagedObjectContext
  
  init(context: NSManagedObjectContext) {
    self.context = context
  }
  
  func fetchBehaviours() -> Effect<[Behaviour], ErrorCase> {
    Deferred { [context] in
      Future<[Behaviour], ErrorCase> { [context] promise in
          do {

            let request: NSFetchRequest<BehaviourEntity> = BehaviourEntity.fetchRequest()
            let result: [BehaviourEntity] = try context.fetch(request)
            let behaviours = try result.mapBehaviorsEntities()
            promise(.success(behaviours))

          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
      }
    }
    .eraseToEffect()
  }
  
  func createBehaviour(id: UUID, emoji: String, name: String) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            let entity = BehaviourEntity(context: context)
            entity.id = id
            entity.emoji = emoji
            entity.name = name
            entity.favorite = false
            entity.archived = false
            entity.pinned = false
            
            try context.save()
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func deleteBehaviour(id: UUID) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            let idPredicate = NSPredicate(format: "id == %@", id as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let object = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            
            context.delete(object)
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func updateBehaviour
  (id: UUID, emoji: String, name: String)
  -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            
            let idPredicate = NSPredicate(format: "id == %@", id as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let object = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            
            object.setValue(emoji, forKey: "emoji")
            object.setValue(name, forKey: "name")
            try context.save()
            
            promise(.success(()))
            
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func updateArchived
  (id: UUID, archived: Bool) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            let idPredicate = NSPredicate(format: "id == %@", id as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let object = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            object.setValue(archived, forKey: "archived")
            object.setValue(false, forKey: "favorite")
            object.setValue(false, forKey: "pinned")
            try context.save()
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func updateFavorite
  (id: UUID, favorite: Bool) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            
            let idPredicate = NSPredicate(format: "id == %@", id as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let object = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            
            object.setValue(favorite, forKey: "favorite")
            try context.save()
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func updatePinned
  (id: UUID, pinned: Bool) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            let idPredicate = NSPredicate(format: "id == %@", id as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let object = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            object.setValue(pinned, forKey: "pinned")
            try context.save()
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func createEntity(for behaviourId: UUID) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          do {
            let idPredicate = NSPredicate(format: "id == %@", behaviourId as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let behaviour = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
            
            let entry = EntryEntity(context: context)
            entry.date = Date()
            behaviour.addToEntries(entry)
            try context.save()
            
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
        }
      }
    }
    .eraseToEffect()
  }
  
  func deleteLastEntry(for behaviourId: UUID) -> Effect<Void, ErrorCase> {
    Deferred { [context] in
      Future<Void, ErrorCase> { [context] promise in
        context.perform {
          
          do {
            let idPredicate = NSPredicate(format: "id == %@", behaviourId as CVarArg)
            let behaviourRequest: NSFetchRequest<BehaviourEntity>
            
            behaviourRequest = BehaviourEntity.fetchRequest()
            behaviourRequest.predicate = idPredicate
            
            guard let behaviour = try context.fetch(behaviourRequest).first else {
              promise(.failure(.notFoundEntity))
              return
            }
           
            let fetchRequest: NSFetchRequest<EntryEntity>
            fetchRequest = EntryEntity.fetchRequest()
            let allEntries = try context.fetch(fetchRequest)
            
            let behaviourEntries = allEntries.filter { entry in
              entry.behaviour == behaviour
            }
            
            if let last = behaviourEntries.last {
              context.delete(last)
            }
            
            try context.save()
            
            promise(.success(()))
          } catch {
            promise(.failure(.genericDbError(error.localizedDescription)))
          }
          
        }
      }
    }
    .eraseToEffect()
  }
}



// TallyGoals/Data/Local.swift
//
//  Local.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//

import Foundation

var presetsCategories: [PresetCategory] {
  
  var cat1 = PresetCategory(emoji: "🙏", name: "Religion & Spiritualité")
  
  cat1.presets = [
    Preset(name: "Prières profondes", isFeatured: true),
    Preset(name: "Répetition de mantra: Je pardonne X"),
    Preset(name: "Aider quelqu'un", isFeatured: true),
    Preset(name: "Jeûne")
  ]
  
  var cat2 = PresetCategory(emoji: "💪", name: "Volonté et discipline")
  cat2.presets = [
    Preset(name: "Resister une tentation", isFeatured: true),
    Preset(name: "Recompense retardée", isFeatured: true),
    Preset(name: "Se lever dès que l'alarme sonne"),
    Preset(name: "Faire quelque chose d'intimidant", isFeatured: true),
    Preset(name: "Sortir de la zone de confort", isFeatured: true),
    Preset(name: "Douche froide"),
    Preset(name: "Commencer par la tâche plus difficile"),
    Preset(name: "Resister l'envie d'acheter quelque chose qu'on n'a pas planifié d'acheter"),
    Preset(name: "Resister l'envie de manger quelque chose qu'on n'a pas planifié de manger")
  ]
  
  var cat3 = PresetCategory(emoji: "🌻", name: "Améliorer le monde")
  cat3.presets = [
    Preset(name: "Appeler ses proches"),
    Preset(name: "Aider quelqu'un", isFeatured: true),
    Preset(name: "Faire une action sociale", isFeatured: true)
  ]
  
  
  var cat4 = PresetCategory(emoji: "💧", name: "Clarté mentale")
 cat4.presets = [
  Preset(name: "Planifier le lendemain"),
  Preset(name: "Ranger bureau à la fin de la journée"),
  Preset(name: "Faire la vaiselle juste après manger", isFeatured: true),
  Preset(name: "Éteindre le wifi"),
  Preset(name: "Activité sans multitâche"),
  Preset(name: "Introspecter à la fin de la journée"),
  Preset(name: "Se déconnecter des résaux sociaux au retour du travail")
 ]
  
  var cat5 = PresetCategory(emoji: "💰", name: "Finances personnelles")
 cat5.presets = [
  Preset(name: "Lire un article sur les criptomonnais"),
  Preset(name: "Resister l'envie d'acheter quelque chose qu'on n'a pas planifié d'acheter")
]
  
  var cat6 = PresetCategory(emoji: "🙂", name: "Bienêtre")
 cat6.presets = [
  Preset(name: "Faire une promenade"),
  Preset(name: "Dopamine detox"),
  Preset(name: "Jeûne"),
  Preset(name: "Pensée négative automatique", isFeatured: true),
  Preset(name: "Resister envie de mal parler de quelqu'un avec qui on a eu un conflit")
]
  
  
  var cat7 = PresetCategory(emoji: "⏰", name: "Gestion du temps")
 cat7.presets = [
  Preset(name: "Se lever à 7:00"),
  Preset(name: "Se coucher à las 22:30")
]
  
  var cat8 = PresetCategory(emoji: "🏋", name: "Sport")
 cat8.presets = [
  Preset(name: "Aller en vélo aux travail"),
  Preset(name: "Aller à pied au travail"),
  Preset(name: "Faire du running")
 ]
  
 var cat9 = PresetCategory(emoji: "🥗", name: "Alimentation")
 cat9.presets = [
  Preset(name: "Repas ketogénique"),
  Preset(name: "Repas avec une grande part de salada"),
  Preset(name: "Journée sans sucre", isFeatured: true)
]
  
  return [cat1, cat2, cat3, cat4, cat5, cat6, cat7, cat8, cat9]
}


// TallyGoals/Data/Persistence.swift
//
//  Persistence.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 27/05/2022.
//

import CoreData

struct PersistenceController {
  
  static let shared = PersistenceController()
  
  struct MockBehaviour {
    let id = UUID()
    let emoji: String
    let name: String
    let archived: Bool
    let favorite: Bool
    let pinned: Bool
  }
  
  static var preview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    
    let initBehaviours = [
      MockBehaviour(
        emoji: "💧",
        name: "Éteindre devices",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "💪",
        name: "Resister une tentation",
        archived: false,
        favorite: true,
        pinned: true
      ),
      MockBehaviour(
        emoji: "🥗",
        name: "Manger keto" ,
        archived: true,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "💪",
        name: "Retarder récompense",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "👔",
        name: "Repasser vêtements",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "⏰",
        name: "Se coucher à 22:30",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "💧",
        name: "Planifier le lendemain",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "🙏",
        name: "Jeûne",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "💧",
        name: "Éteindre le wifi",
        archived: false,
        favorite: false,
        pinned: true
      ),
      MockBehaviour(
        emoji: "⏰",
        name: "Se lever à 7",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "⏰",
        name: "Se lever dès que l'alarme sonne",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🧽",
        name: "Faire la vaiselle just après manger",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "💧",
        name: "Activité sans multitask / pratique déliberée",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🙏",
        name: "Appeler un proche",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🙏",
        name: "Aider quelqu'un",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🥶",
        name: "Douches froides",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🏋️‍♀️",
        name: "Pompes",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🏋️‍♀️",
        name: "Tractions",
        archived: false,
        favorite: false,
        pinned: false
      ),
      MockBehaviour(
        emoji: "🙏",
        name: "Respirer avant d'agir",
        archived: false,
        favorite: false,
        pinned: false
      ),
    ]
    
//    initBehaviours.forEach { behaviour in
//      let entity = BehaviourEntity(context: viewContext)
//      entity.id = behaviour.id
//      entity.emoji = behaviour.emoji
//      entity.name = behaviour.name
//      entity.archived = behaviour.archived
//      entity.favorite = behaviour.favorite
//      entity.pinned = behaviour.pinned
//      viewContext.perform {
//        try! viewContext.save()
//      }
//    }
    
    return result
  }()
  
  let container: NSPersistentCloudKitContainer
  
  init(inMemory: Bool = false) {
    
    container = NSPersistentCloudKitContainer(name: "TallyGoals")
    
    if inMemory {
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    }
    
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        
        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
  }
}


// TallyGoals/DI/Container.swift
import CoreData
let container = Container()

// MARK - Dependency injection, use Swinject instead
final class Container {
  
  var store: AppStore {
    .init(
      initialState: AppState(),
      reducer: appReducer,
      environment: .instance
    )
  }
  
  var context: NSManagedObjectContext {
//    PersistenceController.preview.container.viewContext
    PersistenceController.shared.container.viewContext
  }
  
  var behaviourRepository: BehaviourRepository {
    .init(context: context)
  }
}


// TallyGoals/Domain/Models/Behaviour.swift
import SwiftUI
import SwiftWind
import CoreData

struct Behaviour: Equatable, Identifiable {
  let id: UUID
  var emoji: String
  var name: String
  var pinned: Bool = false
  var archived: Bool = false
  var favorite: Bool = false
  var count: Int
}


// TallyGoals/Domain/Models/Entry.swift
import CoreData
import Foundation

struct Entry: Equatable, Identifiable {
  let id: UUID
  let behaviourId: NSManagedObjectID
  let date: Date
}

struct Goal: Equatable, Identifiable {
  let id: NSManagedObjectID
  let behaviourId: NSManagedObjectID
  let timeStamp: Date
  let goal: Int
  let archived: Bool
}

struct Presets: Equatable, Identifiable {
  let id: NSManagedObjectID
  let emoji: String
  let name: String
}


// TallyGoals/Domain/Models/Error.swift
//
//  Error.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//

import Foundation

enum ErrorCase: Error {
  case genericDbError(String)
  case entityLacksProperty
  case notFoundEntity
  
  
  var title: String {
    switch self {
    case .genericDbError(_):
      return "Fetching db error"
    case .entityLacksProperty:
      return "Db entity problem"
    case .notFoundEntity:
      return "Entity not found"
    }
  }
  
  var message: String {
    switch self {
    case .genericDbError(let errorMessage):
      return errorMessage
    case .entityLacksProperty:
      return "Unable to retrieve all the properties for the entity"
    case .notFoundEntity:
      return "Not entity with id"
    }
  }
}


// TallyGoals/Domain/Models/Overlay.swift
//
//  Overlay.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//

import Foundation

/// Overlay model for presenting a view above the tabBar
enum Overlay: Equatable {
  case exploreDetail(PresetCategory)
  case error(title: String, message: String)
}


// TallyGoals/Domain/Models/Presets.swift
//
//  Presets.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 19/06/2022.
//

import Foundation

struct Preset: Identifiable, Equatable {
  var id: String { name }
  let name: String
  let description: String?
  let isFeatured: Bool
  
  init(
    name: String,
    description: String? = nil,
    isFeatured: Bool = false
  ) {
    self.name = name
    self.description = description
    self.isFeatured = isFeatured
  }
}

struct PresetCategory: Identifiable, Equatable {
  
  let id: UUID
  let emoji: String
  let name: String
  var presets: [Preset]
  
  init(id: UUID = UUID(), emoji: String, name: String, presets: [Preset] = []) {
    self.id = id
    self.emoji = emoji
    self.name = name
    self.presets = presets
  }
}


// TallyGoals/Domain/States/BehaviourState.swift
enum BehaviourState: Equatable {
  case idle
  case loading
  case success([Behaviour])
  case error(String)
  case empty
  
  static
  func make(from array: [Behaviour]) -> BehaviourState {
    if array.isEmpty {
      return .empty
    } else {
      return .success(array)
    }
  }
}


// TallyGoals/Extensions/Constants/Alerts.swift
//
//  Alerts.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI

extension Alert {
  static func deleteAlert(action: @escaping SimpleAction) -> Alert {
    Alert(
      title: Text("Êtes vous sûr de vouloir éliminer ce compteur?"),
      message: Text("Cette action est définitive"),
      primaryButton: .destructive(Text("Éliminer"), action: action),
      secondaryButton: .default(Text("Cancel"))
    )
  }
}


// TallyGoals/Extensions/Constants/CGFloat.swift
//
//  CGFloat.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 29/05/2022.
//

import SwiftUI

extension CGFloat {
  static let horizontal = Self.s4
 
  static let pinnedCellSpacing = Self.s2
  static let pinnedCellRadius = Self.s4
  static let swipeActionWidth = Self.s16
  static let swipeActionTotalWidth = Self.swipeActionWidth * 2
  static let swipeActionsThreshold = Self.swipeActionWidth * 4
  static let swipeActionLaunchingOffset = Self.s3
}


// TallyGoals/Extensions/Constants/Color.swift
//
//  Color.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 29/05/2022.
//

import SwiftUI
import SwiftWind

extension Color {
  static let behaviourRowBackground = Color(uiColor: .systemBackground)
  static let rowPressedColor: WindColor = .sky
  
  static var defaultBackground = Color(UIColor.secondarySystemBackground)
}


// TallyGoals/Extensions/Extensions.swift
import SwiftUI

extension Text {
  
  @ViewBuilder
  static func unwrap(_ optional: String?) -> some View {
    if let safeValue = optional {
      Text(safeValue)
    } else {
      EmptyView()
    }
  }
}

extension Text {
  
  func roundedFont(_ style: Font.TextStyle) -> Text {
    self.font(.system(style, design: .rounded))
  }
}

extension View {
  func roundedFont(_ style: Font.TextStyle) -> some View {
    self.font(.system(style, design: .rounded))
  }
}


extension String: Identifiable {
  public var id: String { self }
}

extension View {
  
  // MARK: - Move to swiftuitilities
  func navigationify() -> some View {
    NavigationView {
      self
    }
  }
  
  func x(_ value: CGFloat) -> some View {
    self.offset(x: value)
  }
  
  func y(_ value: CGFloat) -> some View {
    self.offset(y: value)
  }
  
  func xy(_ value: CGFloat) -> some View {
    self
    .x(value)
    .y(value)
  }
  
  func bindHeight(to value: Binding<CGFloat>) -> some View {
    self
      .modifier(BindingSizeModifier(value: value, dimension: .height))
    
  }
  
  func bindWidth(to value: Binding<CGFloat>) -> some View {
    self
      .modifier(BindingSizeModifier(value: value, dimension: .width))
  }
  
  
  func highPriorityTapGesture(perform action: @escaping () -> Void) -> some View {
    self.highPriorityGesture(
      TapGesture()
        .onEnded(action)
    )
  }
  
  func simultaneusLongGesture(perform action: @escaping () -> Void, animated: Bool = true) -> some View {
    self.simultaneousGesture(
      LongPressGesture()
        .onEnded { _ in
          if animated {
            withAnimation { action() }
          } else {
            action()
          }
        }
    )
  }
  
  @ViewBuilder
  func highPriorityTapGesture(if condition: Bool, action: @escaping () -> Void) -> some View {
    if condition {
      self.highPriorityTapGesture(perform: action)
    } else {
      self
    }
  }
  
  @ViewBuilder
  func highPriorityGesture<T>(if condition: Bool, _ gesture: T, including mask: GestureMask = .all) -> some View where T : Gesture {
    if condition {
      self.highPriorityGesture(gesture)
    } else {
      self
    }
  }
}

extension View {
  func vibrate(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType = .success) {
    UIImpactFeedbackGenerator.shared.impactOccurred()
  }
}

extension ViewModifier {
  func vibrate(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType = .success) {
    UIImpactFeedbackGenerator.shared.impactOccurred()
  }
}

struct BindingSizeModifier: ViewModifier {
  
  @Binding var value: CGFloat
  
  let dimension: Dimension
  
  enum Dimension {
    case width
    case height
  }
  
  func body(content: Content) -> some View {
    content.background(
    GeometryReader { geo in
     Color.clear
        .onAppear {
          switch dimension {
          case .width:
            value = geo.size.width
          case .height:
            value = geo.size.width
          }
        }
    }
    )
  }
}

extension Int {
  var string: String {
    "\(self)"
  }
  
  var cgFloat: CGFloat {
    CGFloat(self)
  }
}

extension Int: Identifiable {
  public var id: Self {
    self
  }
}

extension Array {
  var isNotEmpty: Bool {
    !self.isEmpty
  }
}

extension Array {
  var count: CGFloat {
    self.count.cgFloat
  }
}

extension Array {
  func getOrNil(index: Int) -> Element? {
    guard self.indices.contains(index) else { return nil }
    return self[index]
  }
}

extension UIBarButtonItem {
  
  /// Hides navigation back button label
  static func hideBackButtonLabel() {
    Self.appearance(
      whenContainedInInstancesOf:
        [UINavigationBar.classForCoder() as! UIAppearanceContainer.Type])
      .setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal
      )
  }
}

extension Bool {
  static var isDarkMode: Bool {
    UITraitCollection.current.userInterfaceStyle == .dark
  }
}

typealias NotificationFeedback = UINotificationFeedbackGenerator
extension NotificationFeedback {
  static let shared = UINotificationFeedbackGenerator()
}


extension Array where Element == BehaviourEntity {
  
  func mapBehaviorsEntities() throws -> [Behaviour] {
    
    let behaviours: [Behaviour] = try self.map { entity in
      guard
        let emoji = entity.emoji,
        let name = entity.name,
        let id = entity.id
      else {
        throw ErrorCase.entityLacksProperty
      }

      return Behaviour(
        id: id,
        emoji: emoji,
        name: name,
        pinned: entity.pinned,
        archived: entity.archived,
        favorite: entity.favorite,
        count: entity.entries?.count ?? 0
      )
    }
    
    return behaviours
  }
}


// TallyGoals/Extensions/SimpleAction.swift
//
//  SimpleAction.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import Foundation

typealias SimpleAction = () -> Void


// TallyGoals/Extensions/UIImpactFeedbackGenerator.swift
//
//  UIImpactFeedbackGenerator.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import UIKit

extension UIImpactFeedbackGenerator {
  
  static var shared: UIImpactFeedbackGenerator {
    UIImpactFeedbackGenerator(style: .medium)
  }
}


// TallyGoals/Extensions/UINavigationBar.swift
//
//  UINavigationBar.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//
import UIKit

extension UINavigationBar {
  
  /// Setups default fonts for the navigation bar
  static func setupFonts() {
    var largeTitleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
    let largeTitleDescriptor = largeTitleFont.fontDescriptor.withDesign(.rounded)?
    .withSymbolicTraits(.traitBold)
    
    largeTitleFont = UIFont(descriptor: largeTitleDescriptor!, size: largeTitleFont.pointSize)
    
    var inlineFont = UIFont.preferredFont(forTextStyle: .body)
    let inlineDescriptor = inlineFont.fontDescriptor.withDesign(.rounded)?
      .withSymbolicTraits(.traitBold)
    
    inlineFont = UIFont(descriptor: inlineDescriptor!, size: inlineFont.pointSize)
    
    UINavigationBar.appearance().largeTitleTextAttributes = [.font : largeTitleFont]
    UINavigationBar.appearance().titleTextAttributes = [.font: inlineFont]
  }
}


// TallyGoals/Screens/Add/AddScreen.swift
import Combine
import ComposableArchitecture
import SwiftUI

struct AddScreen: View {
  @Environment(\.presentationMode) var presentationMode
  let store: Store<AppState, AppAction>
  
  @State var emoji: String = ""
  @State var name : String = ""
  
  var body: some View {
    WithViewStore(store) { viewStore in
      
      Form {
        
        EmojiTextField("Emoji", text: $emoji)
        TextField("Titre",   text: $name)
      }
      .toolbar { 
        Text("Enregistrer")
          .onTap {
            viewStore.send(
              .createBehaviour(
                id: UUID(),
                emoji: emoji, 
                name: name
              ))
            pop()
          }
          .disabled(
            emoji.isEmpty || name.isEmpty
          )
      }
      
    }
    .onTapDismissKeyboard()
  }
  
  func pop() {
    presentationMode.wrappedValue.dismiss()
  }
}



// TallyGoals/Screens/Archive/ArchivedScreen.swift
import ComposableArchitecture
import SwiftUI

struct ArchivedScreen: View {
  
  let store: Store<AppState, AppAction>
  
  var body: some View {
    WithViewStore(store) { viewStore in
      
      switch viewStore.state.behaviourState {
      case .idle, .loading:
        ProgressView()
      case .success(let model):
        let model = getArchived(from: model)
        
        if model.isEmpty {
          ListEmptyView(symbol: "archivebox")
        } else { 
          LazyVStack {
            ForEach(model) { item in
              BehaviourRow(
                model: item,
                archived: true,
                viewStore: viewStore
              )
            }
            
            Spacer()
          }
        
          .scrollify()
        }
      case .empty:
        ListEmptyView(symbol: "archivebox")
      case .error(let message):
        Text(message)
      }
    }
  } 
  
  func getArchived(from behaviourList: [Behaviour]) -> [Behaviour] {
    behaviourList.filter { $0.archived }
  }
}


// TallyGoals/Screens/Edit/BehaviourEditScreen.swift
import ComposableArchitecture
import SwiftUI

struct BehaviourEditScreen: View {
  
  @Environment(\.presentationMode) var presentationMode
  let viewStore: AppViewStore
  let item: Behaviour
  
  @State var emoji: String
  @State var name: String
  
  var body: some View {
      VStack {
      
        Form { 
          
          Section { 
            TextField("Emoji", text: $emoji)
              .onChange(of: emoji) { newValue in
                emoji = String(newValue.prefix(1))
              }
            TextField("Titre", text: $name)
          }
        }
        
      }
      .toolbar { 
        Text("Enregistrer")
          .onTap {
            viewStore.send(
              .updateBehaviour(
                id: item.id, 
                emoji: emoji,
                name: name
              ))
            pop()
          }
          .disabled(
            emoji == item.emoji && name == item.name
          )
      }
  }
  
  func pop() {
    presentationMode.wrappedValue.dismiss()
  }
}


// TallyGoals/Screens/Explore/ExplorePresetCard.swift
//
//  ExplorePresetCard.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 19/06/2022.
//

import SwiftUI
import SwiftWind

struct ExplorePresetCard: View {
  
  @State var showDetail = false
  let model: PresetCategory
  let viewStore: AppViewStore
  
  var body: some View {
//    Color.clear
//    .background(.thinMaterial)
    background
    .cornerRadius(.s3)
    .aspectRatio(1, contentMode: .fit)
    .overlay(labelStack)
    .onTap {
      viewStore.send(.setOverlay(overlay: .exploreDetail(model)))
      
    }
    .buttonStyle(.plain)
    .navigationLink(detailScreen, $showDetail)
  }
  
  
  
  var background: some View {
    VerticalLinearGradient(colors: [
      .isDarkMode ? WindColor.zinc.c600 : WindColor.zinc.c100,
      .isDarkMode ? WindColor.zinc.c700 : WindColor.zinc.c200
    ])
  }
  
  var detailScreen: some View {
    PresetCategoryDetailScreen(model: model, viewStore: viewStore)
  }
  
  var labelStack: some View {
    VStack(spacing: .s6) {
      Text(model.emoji)
//      .font(.system(size: .s14))
      .font(.largeTitle)
      Text(model.name)
      .roundedFont(.subheadline)
      .fontWeight(.bold)
      .frame(maxWidth: .s28)
      .multilineTextAlignment(.center)
    }
  }
}


// TallyGoals/Screens/Explore/ExploreScreen.swift
//
//  ExploreScreen.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 13/06/2022.
//

import SwiftUI
import SwiftUItilities
import SwiftWind




struct ExploreScreen: View {
  @State var showDetail = false
  @GestureState var isPressed = false
  
  @Namespace var namespace
  let viewStore: AppViewStore
  
  
  private let columns = [
    GridItem(.flexible(), spacing: .s4),
    GridItem(.flexible(), spacing: .s4)
  ]
  
  let feauredModel = presetsCategories.map { presetCategory in
    return (presetCategory, presetCategory.presets.filter { $0.isFeatured })
  }
  
  var body: some View {
      DefaultVStack {
        
        LazyVGrid(columns: columns, spacing: .s4) {
          
          ForEach(presetsCategories) { category in
            ExplorePresetCard(model: category, viewStore: viewStore)
          }
        }
      }
      .horizontal(.s4)
      .vertical(.s6)
      .scrollify()
  }
}


// TallyGoals/Screens/Explore/PresetCategoryDetailScreen.swift
//
//  PresetCategoryDetailScreen.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 19/06/2022.
//

import SwiftUI
import SwiftUItilities

struct PresetCategoryDetailScreen: View {
  
  let model: PresetCategory
  let viewStore: AppViewStore
  
  var body: some View {
    VStack {
      Text(model.emoji)
        .top(.s6)
        .font(.largeTitle)
      Text(model.name)
        .roundedFont(.title2)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)
        .top(.s2)
      
      DefaultVStack {
        ForEach(model.presets) { preset in
          PresetRow(
            emoji: model.emoji,
            model: preset,
            viewStore: viewStore
          )
          .padding(.s3)
        }
      }
      .horizontal(.horizontal)
    }
    .scrollify()
    .overlay(
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .size(.s5)
        .onTap {
          viewStore.send(.setOverlay(overlay: nil))
        }
        .buttonStyle(.plain)
        .padding(.s4)
      ,alignment: .topTrailing
    )
    .background(
      Color.clear.background(.thinMaterial)
    )
  }
}


// TallyGoals/Screens/Explore/PresetRow.swift
//
//  PresetRow.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 19/06/2022.
//

import SwiftUI
import SwiftWind

struct PresetRow: View {
  
  @State var added: Bool = false
  
  let emoji: String
  let model: Preset
  let viewStore: AppViewStore
  
  var body: some View {
    HStack {
      Text(model.name)
        .roundedFont(.body)
      Spacer()
      addButton
    }
  }
  
  var addButton: some View {
    Text(added ? "Rajouté".uppercased() : "Rajouter".uppercased())
      .font(.caption)
      .fontWeight(.bold)
      .vertical(.s1h)
      .horizontal(.s3)
      .background(background.cornerRadius(.s60))
      .onTap {
        viewStore.send(
          .createBehaviour(
            id: UUID(),
            emoji: emoji,
            name: model.name
          )
        )
        added = true
      }
      .disabled(added)
      .animation(.spring(), value: added)
  }
  
  @ViewBuilder
  var background: some View {
    .isDarkMode ? WindColor.neutral.c600 : WindColor.neutral.c100
  }
}



// TallyGoals/Screens/Goals/GoalsScreen.swift
import ComposableArchitecture
import SwiftUI

struct GoalRow: View {
  
  @State var done: Int = .zero
  let goal: Int = 20
  
  private var goalLabel: String {
    done.string + " / " + goal.string
  }
  
  private var progression: Double {
    Double(done) / Double(goal)
  }
  
  var body: some View {
    
    VStack {
      HStack {
        Text("⏰")
        
        Text("Levantarse a las 7:00 AM")
        
        
        Spacer()
        Text(goalLabel)
        
      }
      .font(.caption)
      
      GeometryReader { geo in
        Rectangle()
          .foregroundColor(Color(UIColor.secondarySystemBackground))
          .height(1)
          .overlay(
            Rectangle()
              .width(geo.size.width * progression)
              .foregroundColor(.blue300)
              .height(1),
            alignment: .leading
          )
      }
    }
    //.vertical(8)
    .onTap {
      withAnimation { done += 1 }
    }
    .buttonStyle(.plain)
    
  }
}

struct LongTermGoalRow: View {
  
  @State var done: Int = .zero
  let goal: Int = 80
  
  private var goalLabel: String {
    done.string + " / " + goal.string
  }
  
  private var progression: Double {
    Double(done) / Double(goal) 
  }
  
  private var level: Int {
    Int(Double(done) / Double(goal) * 10) 
  }
  
  var body: some View {
    HStack {
      Circle()
        .stroke(
          style: StrokeStyle(
            lineWidth: 2.0, 
            lineCap: .round, 
            lineJoin: .round)
        )
        .foregroundColor(Color.defaultBackground)
        .size(50)
        .overlay(
          Image(level.string)
            .resizable()
            .size(40)
            .clipShape(Circle())
        )
        .overlay(
          Circle()
            .trim(
              from: 0.0, 
              to: CGFloat(min(progression, 1.0)
                         )
            )
            .stroke(
              style: StrokeStyle(
                lineWidth: 2.0, 
                lineCap: .round, 
                lineJoin: .round)
            )
            .foregroundColor(.blue300)
            .rotationEffect(Angle(degrees: 270.0))
          
        )
      
      
      Text("💧 Behaviour name")
      
      Spacer()
      
      Text(goalLabel)
    }
    .font(.caption)
    .onTap {
      withAnimation {
        done += 1
      }
    }
    .buttonStyle(.plain)
  }
  
  var levelBadge: some View {
    Text("Lvl \(level)")
      .fontWeight(.bold)
      .font(.caption2)
      .foregroundColor(.blue300)
      .horizontal(4)
      .background(
        Color(UIColor.secondarySystemBackground)
          .cornerRadius(12)
      )
      .x(4)
      .y(4)
  }
}

struct GoalsScreen: View {
  @State var selection: Int = .zero
  let store: AppStore
  
  var body: some View {
    WithViewStore(store) { viewStore in
      
      LazyVStack {
        
        Picker("What is your favorite color?", selection: $selection) {
          
          Text("Short term").tag(0)
          Text("Long term").tag(1)
          
        }
        .pickerStyle(.segmented)
        .bottom(24)
        
        switch selection {
        case 0:
          ForEach(1...10, id: \.self) { int in
            GoalRow()
          }
        case 1:
          ForEach(1...10, id: \.self) { int in
            LongTermGoalRow()
          }
        default: EmptyView()
        }
        
        
        
      }
      .horizontal(24)
      .bottom(24)
      .scrollify()
      
      
    }
    .navigationTitle("Goals")    
    .toolbar {
      Image(systemName: "plus")
        .onTap(navigateTo: AddGoalScreen(store: store)) 
    }
  }
  
  
}

struct AddGoalScreen: View {
  
  @State var count: Int = .zero
  
  let store: AppStore
  
  var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        HStack {
          Text("Goal")
          Spacer()
          Text("-")
            .onTap(perform: decrease)
          Text(count.string)
          Text("+")
            .onTap(perform: increment)
        }
        Spacer()
      }
      .horizontal(8)
      .toolbar {
        Text("Save")
          .onTap {
            print("tapped saved button")
          }
          .disabled(true)
      }
      
    }
  }
  
  func decrease() {
    guard count > 0 else { return }
    count -= 1
  }
  
  func increment() {
    count += 1
  }
}


// TallyGoals/Screens/Home/ArrayFilters.swift
//
//  ArrayFilters.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 29/05/2022.
//

import Foundation

extension Array where Element == Behaviour {
  
  var defaultFilter: Self {
    self
      .filter { !$0.archived }
      .filter { !$0.pinned }
      .sorted(by: { $0.name < $1.name })
      .sorted(by: { $0.emoji < $1.emoji })
  }
  
  var pinnedFilter: Self {
    self
      .filter { !$0.archived }
      .filter { $0.pinned }
      .sorted(by: { $0.name < $1.name })
      .sorted(by: { $0.emoji < $1.emoji })
  }
}


// TallyGoals/Screens/Home/Grid/BehaviourCard.swift
//
//  BehaviourCard.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI
import SwiftWind
import SwiftUItilities

struct BehaviourCard: View {
  
  @State var showEditingScreen = false
  @State var showDeletingAlert = false
  
  let model: Behaviour
  let viewStore: AppViewStore

  var body: some View {
      background
      .cornerRadius(.s4)
      .aspectRatio(1, contentMode: .fill)
      .overlay(
        Text(model.emoji)
        .font(.caption)
        .padding()
        , alignment: .topTrailing
      )
//      .overlay(chevronIcon, alignment: .topLeading)
      .overlay(labelStack, alignment: .bottomLeading)
      .onTap(perform: increase)
      .buttonStyle(.plain)
      .contextMenu { contextMenuContent }
      .navigationLink(editScreen, $showEditingScreen)
      .alert(isPresented: $showDeletingAlert) { .deleteAlert(action: delete) }
  }
  
  @ViewBuilder
  var contextMenuContent: some View {
    Label("Unpin", systemImage: "pin").onTap(perform: unpin)
    Label("Decrease", systemImage: "minus.circle").onTap(perform: decrease).displayIf(model.count > 0)
    Label("Edit", systemImage: "pencil").onTap(perform: goToEditScreen)
    Label("Archive", systemImage: "archivebox").onTap(perform: archive)
    
    Button(role: .destructive) {
      showDeletingAlert = true
    } label: {
      Label("Delete", systemImage: "trash").onTap {}
    }
  }
  
//  var chevronIcon: some View {
//    Image(systemName: "chevron.right")
//    .foregroundColor(WindColor.gray.c400)
//    .padding(.s3)
//    .displayIf(viewStore.state.isEditingMode)
//  }
  
  var labelStack: some View {
    DefaultVStack {
      Text(model.count.string)
        .fontWeight(.bold)
        .font(.system(.title2, design: .rounded))
      Text(model.name)
        .fontWeight(.bold)
        .font(.system(.caption, design: .rounded))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
    .foregroundColor(.isDarkMode ? .white : WindColor.zinc.c700)
    .padding(.s3)
  }
  
  var editScreen: some View {
    BehaviourEditScreen(
      viewStore: viewStore,
      item: model,
      emoji: model.emoji,
      name: model.name
    )
  }
  
  var background: some View {
    VerticalLinearGradient(colors: [
      .isDarkMode ? WindColor.zinc.c600 : WindColor.zinc.c100,
      .isDarkMode ? WindColor.zinc.c700 : WindColor.zinc.c200
    ])
  }
  
  func delete() {
    viewStore.send(.deleteBehaviour(id: model.id))
  }
  
  func goToEditScreen() {
    showEditingScreen = true
  }
  
  func archive() {
    viewStore.send(.updateArchive(id: model.id, archive: true))
  }
  
  func unpin() {
    viewStore.send(.updatePinned(id: model.id, pinned: false))
  }
  
  func decrease() {
    vibrate()
    viewStore.send(.deleteEntry(behaviour: model.id))
  }
  
  func increase() {
    vibrate()
    viewStore.send(.addEntry(behaviour: model.id))
  }
}


// TallyGoals/Screens/Home/Grid/BehaviourGrid.swift
import Algorithms
import ComposableArchitecture
import SwiftUI
import SwiftUItilities
import SwiftWind

struct BehaviourGrid: View {
  
  @State private var page: Int = .zero
  @State private var cellHeight: CGFloat = .zero
  
  let model: [Behaviour]
  let store: AppStore
  

  private let columns = [
    GridItem(.flexible(), spacing: .pinnedCellSpacing),
    GridItem(.flexible(), spacing: .pinnedCellSpacing),
    GridItem(.flexible(), spacing: .pinnedCellSpacing)
  ]
  
  private var tabViewHeight: CGFloat {
    let numberOfRows: CGFloat = 2
    return cellHeight * numberOfRows + .pinnedCellSpacing
  }
  
  private var chunkedModel: [[Behaviour]] {
    model.chunks(ofCount: 6).map(Array.init)
  }
  
  var body: some View {
    WithViewStore(store) { viewStore in
      
      if model.count > 3 {
      TabView(selection: $page) {
        ForEach(0...chunkedModel.count - 1) { index in
          let chunk = chunkedModel[index]
          grid(model: chunk, viewStore: viewStore)
          .horizontal(.horizontal)
        }
       
      }
      .height(tabViewHeight)
      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
      .overlay(indexView, alignment: .bottomTrailing)
    
      } else {
        grid(
          model: model,
          viewStore: viewStore,
          addFillers: false
        )
        .horizontal(.horizontal)
      }
    }
    .animation(.easeInOut, value: model)
  }
  
  var indexView: some View {
      PagerIndexView(
        currentIndex: page,
        maxIndex: chunkedModel.count - 1
      )
      .x(-.horizontal)
      .y(.s4)
      .displayIf(chunkedModel.count > 1)
  }
  
  func grid(model: [Behaviour], viewStore: AppViewStore, addFillers: Bool = true) -> some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: .pinnedCellSpacing) {
      ForEach(model) { item in
        BehaviourCard(model: item, viewStore: viewStore)
          .bindHeight(to: $cellHeight)
      }
     
      if addFillers {
        fills(delta: 6 - model.count)
      }
    }
  }
 
  @ViewBuilder
  func fills(delta: Int) -> some View {
    if delta > 0 {
     
      ForEach(1...delta) { _ in
        emptyCell
      }
    }
  }
  
  var emptyCell: some View {
    Color.clear
    .aspectRatio(1, contentMode: .fill)
  }
}



// TallyGoals/Screens/Home/HomeScreen.swift
import Algorithms
import ComposableArchitecture
import CoreData
import SwiftUI
import SwiftUItilities
import SwiftWind

struct HomeScreen: View {
  
  let store: Store<AppState, AppAction>
  @State var emoji = ""
  var body: some View {
    
    WithViewStore(store) { viewStore in
      
      VStack {
        switch viewStore.state.behaviourState {
        case .idle, .loading:
          progressView(viewStore: viewStore)
        case .success(let model):
          
          
          DefaultVStack {
            
            BehaviourGrid(
              model: model.pinnedFilter,
              store: store
            )
            .top(.s6)
            .displayIf(model.pinnedFilter.isNotEmpty)
            
              LazyVStack(spacing: 0) {
                ForEach(model.defaultFilter) { item in
                  BehaviourRow(
                    model: item,
                    viewStore: viewStore
                  )
                }
              }
              .background(Color.behaviourRowBackground)
              .top(model.pinnedFilter.isEmpty ? .zero : .s4)
              .bottom(.s6)
              .animation(.easeInOut, value: model.defaultFilter)
            
            
          }
          .scrollify()
          .onTapDismissKeyboard()
          .overlay(
            emptyView.displayIf(model.defaultFilter.isEmpty && model.pinnedFilter.count <= 3)
          )
          
        case .empty:
          emptyView
        case .error(let message):
          Text(message)
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
          Image(systemName: "plus")
            .onTap {
              AddScreen(store: store)
            }
        }
      }
    }
  }
}


// MARK: - UI components
private extension HomeScreen {
  
  func progressView
  (viewStore: AppViewStore) -> some View {
    ProgressView()
      .onAppear {
        viewStore.send(.readBehaviours)
      }
  }
  
  var emptyView: some View {
    ListEmptyView(symbol: "house")
  }
}



// TallyGoals/Screens/Home/Row/BehaviourRow.swift
//
//  BehaviourRow.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 27/05/2022.
//

import SwiftUI
import SwiftUItilities
import SwiftWind
import ComposableArchitecture

struct BehaviourRow: View {
  
  @State var showEditScreen = false
  @State var showDeletingAlert = false
  
  let model: Behaviour
  let archived: Bool
  let viewStore: AppViewStore
 
  init(model: Behaviour, archived: Bool = false, viewStore: AppViewStore) {
    self.model = model
    self.viewStore = viewStore
    self.archived = archived
  }
  
  
  var body: some View {
    
    rowCell
      .background(Color.behaviourRowBackground)
      .navigationLink(editScreen, $showEditScreen)
      .sparkSwipeActions(
        leading: archived ? [] : leadingActions,
        trailing: trailingActions
      )
      .onTap(perform: increase)
      .buttonStyle(.plain)
      .alert(isPresented: $showDeletingAlert) { .deleteAlert(action: delete) }
  }
  
  var rowCell: some View {
    HStack(spacing: 0) {
      
      Text(model.emoji)
        .font(.caption2)
        .grayscale(archived ? 1 : 0)
      
      Text(model.count.string)
        .font(.system(.largeTitle, design: .rounded))
        .fontWeight(.bold)
        .horizontal(.s3)
      
        Text(model.name)
          .fontWeight(.bold)
          .font(.system(.body, design: .rounded))
          .lineLimit(2)
        
        Spacer()
    }
    .horizontal(.horizontal)
    .vertical(.s3)
    .overlay(divider, alignment: .bottomTrailing)
  }
}

// MARK: - SwipeActions
private extension BehaviourRow {
  var leadingActions: [SwipeAction] {
    [
      SwipeAction(
        label: "Épingler",
        systemSymbol: "pin.fill",
        action: pin,
        backgroundColor: .blue500
      ),
      SwipeAction(
        label: "Éditer",
        systemSymbol: "pencil",
        action: goToEditScreen,
        backgroundColor: .lime600
      ),
      SwipeAction(
        label: "Réduir d'une unité",
        systemSymbol: "minus.circle",
        action: decrease,
        backgroundColor: .yellow600
      )
    ]
  }
  
  var trailingActions: [SwipeAction] {
    [
      SwipeAction(
        label: "Effacer",
        systemSymbol: "trash",
        action: showAlert,
        backgroundColor: .red500
      ),
      SwipeAction(
        label: archived ? "Désarchiver" : "Archiver",
        systemSymbol: "archivebox",
        action: archive,
        backgroundColor: .orange400
      )
    ]
  }
}

// MARK: - UI
private extension BehaviourRow {
  var editScreen: some View {
    BehaviourEditScreen(
      viewStore: viewStore,
      item: model,
      emoji: model.emoji,
      name: model.name
    )
  }

  var divider: some View {
    let color = .isDarkMode ? WindColor.gray.c800 : WindColor.gray.c100
    return Rectangle()
      .foregroundColor(color)
      .height(.px)
  }
}

// MARK: - Methods
private extension BehaviourRow {
  
  func increase() {
    vibrate()
    withAnimation {
      guard !archived else { return }
      viewStore.send(.addEntry(behaviour: model.id))
    }
  }
  
  func decrease() {
    guard model.count > 0 else {
      vibrate(.error)
      return
    }
    
    vibrate()
    withAnimation {
      viewStore.send(.deleteEntry(behaviour: model.id))
    }
  }
  
  func goToEditScreen() {
    showEditScreen = true
  }
  
  func pin() {
    viewStore.send(.updatePinned(id: model.id, pinned: true))
  }
  
  func archive() {
    viewStore.send(.updateArchive(id: model.id, archive: !archived))
  }
  
  func delete() {
    viewStore.send(.deleteBehaviour(id: model.id))
  }
  
  func showAlert() {
    showDeletingAlert = true
  }
}


// TallyGoals/Screens/Onboarding/OnboardingScreen.swift
//
//  OnboardingScreen.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//
import ComposableArchitecture
import SwiftUI

struct OnboardingScreen: View {
  @AppStorage("showOnboarding") var showOnboarding: Bool = true
  @State var page: Int = .zero
  let store: AppStore
  private let betterWorldModel = presetsCategories.filter { $0.emoji == "🌻" }.first!
  
  var body: some View {
    
    WithViewStore(store) { viewStore in
      TabView(selection: $page) {
        
        VStack(spacing: 0) {
          
          Text("Bienvenu a TallyGoals")
            .roundedFont(.title)
            .fontWeight(.bold)
          
          Text("L'application qui vous aide à améliorer le monde a travers la réeducation du comportement")
            .top(.s2)
          
          Text("Suivant")
            .top(.s6)
            .onTap {
              page += 1
            }
          
        }
        .tag(0)
        .horizontal(.horizontal)
        
        VStack {
          Text("Pour utiliser l'application, vous chossirez le(s) comportement(s) que vous souhaitez adopter")
          
          Text("Par example:")
            .fontWeight(.bold)
            .top(.s2)
          
          Text("🙏 Aider quelqu'un")
          
          
          Text("Compris")
            .onTap { page += 1 }
            .top(.s6)
        }
        .tag(1)
        .horizontal(.horizontal)
        
        VStack {
          Text("Chaque fois que vous adoptez ce comportement:")
            .roundedFont(.headline)
            .fontWeight(.bold)
          
          
          Text("1. Ouvrez l'application")
            .top(.s2)
          Text("2. Incrementez le compteur associé")
          
          Text("Suivant")
            .top(.s6)
            .onTap {
              page += 1
            }
        }
        .tag(2)
        .horizontal(.horizontal)
        
        
        VStack {
          
          Text("En ce faisant, vous:")
            .roundedFont(.headline)
          Text("1. Prenez conscience du comportement, des situations et des opportunités pour l'adopter")
            .top(.s4)
          Text("2. Obtenez la satisfaction d'incrementer le compteur")
            .top(.s1)
          
          Text("Compris")
            .top(.s6)
            .onTap {
              page += 1
            }
        }
        .tag(3)
        .horizontal(.horizontal)
        
        VStack {
          
          Text("Quelques examples")
            .roundedFont(.headline)
          
          ForEach(betterWorldModel.presets) { item in
            PresetRow(
              emoji: "🌻",
              model: item,
              viewStore: viewStore
            )
          }
          
          Text("Compris")
            .top(.s6)
            .onTap {
              showOnboarding = false
            }
        }
        .tag(4)
        .horizontal(.horizontal)
      }
      
      .roundedFont(.body)
      .multilineTextAlignment(.center)
      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
  }
}




// TallyGoals/UI/BindingPressStyle.swift
//
//  BindingPressStyle.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 19/06/2022.
//

import SwiftUI

struct BindingPressStyle: ButtonStyle {
  
  @Binding var isPressed: Bool
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .onChange(of: configuration.isPressed) { newValue in
        isPressed = newValue
      }
  }
}


// TallyGoals/UI/EmojiField.swift
//
//  EmojiField.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI

struct EmojiField: View {
  @Binding var text: String
  let placeholder: String
  
  init(
    _ placeholder: String,
    text: Binding<String>
  ) {
    self._text = text
    self.placeholder = placeholder
  }
  
  var body: some View {
    TextField("Emoji", text: $text)
      .onChange(of: text) { newValue in
        guard newValue.containsEmoji else {
          text = ""
          return
        }
        if newValue.count == 2 {
          text = String(newValue[1])
        } else {
          text = String(newValue.prefix(1))
        }
      }
  }
}

extension Character {
    /// A simple emoji is one scalar and presented to the user as an Emoji
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }

    /// Checks if the scalars will be merged into an emoji
    var isCombinedIntoEmoji: Bool { unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false }

    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}

extension String {
    var isSingleEmoji: Bool { count == 1 && containsEmoji }

    var containsEmoji: Bool { contains { $0.isEmoji } }

    var containsOnlyEmoji: Bool { !isEmpty && !contains { !$0.isEmoji } }

    var emojiString: String { emojis.map { String($0) }.reduce("", +) }

    var emojis: [Character] { filter { $0.isEmoji } }

    var emojiScalars: [UnicodeScalar] { filter { $0.isEmoji }.flatMap { $0.unicodeScalars } }
}


extension StringProtocol {
    subscript(_ offset: Int)                     -> Element     { self[index(startIndex, offsetBy: offset)] }
    subscript(_ range: Range<Int>)               -> SubSequence { prefix(range.lowerBound+range.count).suffix(range.count) }
    subscript(_ range: ClosedRange<Int>)         -> SubSequence { prefix(range.lowerBound+range.count).suffix(range.count) }
    subscript(_ range: PartialRangeThrough<Int>) -> SubSequence { prefix(range.upperBound.advanced(by: 1)) }
    subscript(_ range: PartialRangeUpTo<Int>)    -> SubSequence { prefix(range.upperBound) }
    subscript(_ range: PartialRangeFrom<Int>)    -> SubSequence { suffix(Swift.max(0, count-range.lowerBound)) }
}

class UIEmojiTextField: UITextField {

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setEmoji() {
        _ = self.textInputMode
    }
    
    override var textInputContextIdentifier: String? {
           return ""
    }
    
    override var textInputMode: UITextInputMode? {
      var emojiMode: UITextInputMode?
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                self.keyboardType = .default // do not remove this
                emojiMode = mode
            }
        }
        return emojiMode
    }
}

struct EmojiTextField: UIViewRepresentable {
  let placeholder: String
    @Binding var text: String
  
  init(
    _ placeholder: String,
    text: Binding<String>
  ) {
    self._text = text
    self.placeholder = placeholder
  }
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.placeholder = placeholder
        emojiTextField.text = text
        emojiTextField.delegate = context.coordinator
        return emojiTextField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        
        init(parent: EmojiTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
              guard let newValue = textField.text else { return }
                self?.parent.text = textField.text ?? ""
              
              guard newValue.containsEmoji else {
                self?.parent.text = ""
                return
              }
              if newValue.count == 2 {
                self?.parent.text = String(newValue[1])
              } else {
                self?.parent.text = String(newValue.prefix(1))
              }
              
            }
        }
    }
}


// TallyGoals/UI/ErrorView.swift
//
//  ErrorView.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//

import SwiftUI
import SwiftUItilities

struct ErrorView: View {
  
  let title: String
  let message: String
  let viewStore: AppViewStore
  
  var body: some View {
    VStack(spacing: 0) {
      Text(title)
        .roundedFont(.body)
        .bold()
      
      Text(message)
      .top(.s1)
      
      Text("Ok")
        .onTap {
          viewStore.send(.setOverlay(overlay: nil))
        }
      .top(.s1)
    }
    .padding()
    .width(.s48)
    .cornerRadius(.s6)
    .background(.thinMaterial)
    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
  }
}


// TallyGoals/UI/ListEmptyView.swift
//
//  ListEmptyView.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 26/06/2022.
//

import SwiftUI
struct ListEmptyView: View {
  
  let symbol: String
  
  var body: some View {
    Image(systemName: symbol)
      .resizable()
      .width(50)
      .height(40)
      .foregroundColor(.gray)
      .opacity(0.2)
  }
}


// TallyGoals/UI/PagerIndexView.swift
//
//  PagerIndexView.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI
import SwiftWind

struct PagerIndexView: View {
  
  let currentIndex: Int
  let maxIndex: Int
  
  var body: some View {
    HStack {
      ForEach(0...maxIndex) { index in
        let isSelected = currentIndex == index
        Circle()
          .size(.s1)
          .foregroundColor(foreground(isSelected: isSelected))
          .animation(.easeInOut, value: isSelected)
      }
    }
    .padding(.s1)
    .animation(.easeInOut, value: maxIndex)
  }
  
  @ViewBuilder
  var background: some View {
    if .isDarkMode {
      WindColor.neutral.c500
    } else {
      WindColor.neutral.c300
    }
  }
  
  func foreground(isSelected: Bool) -> Color {
    if isSelected {
      if .isDarkMode {
        return WindColor.neutral.c200
      } else {
        return WindColor.neutral.c500
      }
    } else {
      if .isDarkMode {
        return WindColor.neutral.c500
      } else {
        return WindColor.neutral.c200
      }
    }
  }
}


// TallyGoals/UI/toDo/Legacify/FavoriteScreen.swift
//import ComposableArchitecture
//import SwiftUI
//
//struct FavoritesScreen: View {
//  
//  let store: Store<AppState, AppAction>
//  
//  var body: some View {
//    WithViewStore(store) { viewStore in
//      
//      switch viewStore.behaviourState {
//      case .idle, .loading:
//        ProgressView()
//          .onAppear {
//            viewStore.send(.readBehaviours)
//          }
//      case .success(let model):
//        let model = getFavorites(from: model)
//        
//        if model.isEmpty {
//          ListEmptyView(symbol: "star.fill")
//        } else {
//          List(model) { item in
//            ListRow(
//              store: store,
//              item: item
//            )
//              .onTap {
//                withAnimation {
//                  viewStore.send(
//                    .addEntry(behaviour: item.id)
//                  )
//                }
//              }
//              .buttonStyle(.plain)
//              .swipeActions(edge: .trailing) {
//                swipeActionStack(
//                  viewStore: viewStore,
//                  item: item
//                )
//              }
//              .swipeActions(edge: .leading) {
//                Label("Pin", systemImage: "pin")
//                  .onTap {
//                    withAnimation {
//                      viewStore.send(.updatePinned(
//                        id: item.id,
//                        pinned: !item.pinned
//                      )
//                      )
//                    }
//                  }
//                  .tint(item.pinned ? .gray : .indigo)
//              }
//          }
//          .navigationTitle("Favorites")
//        }
//      case .empty:
//        Text("Not items yet")
//      case .error(let message):
//        Text(message)
//      }
//    }
//  }
//  
//  @ViewBuilder
//  func swipeActionStack
//  (viewStore: AppViewStore, item: Behaviour) -> some View {
//    Label("Favorite", systemImage: "star")
//      .onTap {
//        viewStore.send(.updateFavorite(
//          id: item.id,
//          favorite: false)
//        )
//      }
//      .tint(.gray)
//    
//    Button(role: .destructive) {
//      withAnimation {
//        viewStore.send(.deleteBehaviour(id: item.id))
//      }
//    } label: {
//      Label("Delete", systemImage: "trash.fill")
//    }
//  }
//  
//  func getFavorites
//  (from behaviourList: [Behaviour]) -> [Behaviour] {
//    behaviourList
//      .filter { $0.favorite }
//      .filter { !$0.archived }
//      .sorted(by: { $0.emoji < $1.emoji })
//      .sorted(by: { $0.name < $1.name })
//      .sorted(by: { $0.pinned && !$1.pinned })
//  }
//}
//



// TallyGoals/UI/toDo/Legacify/LegacyBehaviourCard.swift
//import ComposableArchitecture
//import CoreData
//import SwiftUI
//import SwiftUItilities
//import SwiftWind
//
//struct LegacyBehaviourCard: View {
//  
//  @State var showEdit: Bool = false
//  
//  let model: Behaviour
//  let store: AppStore
//  
//  var body: some View {
//    WithViewStore(store) { viewStore in
//      VStack(alignment: .leading) {
//        Rectangle()
//          .foregroundColor(Color(UIColor.secondarySystemBackground))
//          .size(80)
//          .cornerRadius(8)
//          .overlay(Text(model.emoji))
//          .overlay(
//            
//            Badge(number: getCount(
//              behaviourId: model.id, 
//              viewStore: viewStore
//            ), color: model.color)
//              .x(10)
//              .y(-10)
//            ,
//            alignment: .topTrailing
//            
//          )
//          .onTap {
//            viewStore.send(.addEntry(behaviour: model.id))
//          }
//        
//        
//        Text(model.name)
//          .width(80)
//          .font(.caption)
//          .lineLimit(2)
//          .fixedSize(
//            horizontal: false, 
//            vertical: true
//          )
//          .height(40)
//        
//      }
////      .background(editLink)
//      .contextMenu {
//        Label("Edit", systemImage: "pencil")
//          .onTap {
//            showEdit = true
//          }
//        Label("Unpin", systemImage: "pin")
//          .onTap {
//            viewStore.send(.updatePinned(id: model.id, pinned: false))
//          }
//      }
//    }
//  }
//  
////  var editLink: some View {
////    EmptyNavigationLink(
////      destination: behaviourEditScreen,
////      isActive: $showEdit
////    )
////  }
//  
////  var behaviourEditScreen: some View {
////    BehaviourEditScreen(
////      store: store,
////      item: model,
////      emoji: model.emoji,
////      name: model.name
////    )
////  }
//}
//
//struct Badge: View {
//  
//  let number: Int
//  let color: WindColor
//  let small: Bool
//  let dark: Bool
//  
//  init(number: Int, color: WindColor, small: Bool = false, dark: Bool = true) {
//    self.number = number
//    self.color = color
//    self.small = small
//    self.dark = dark
//  }
//  
//  var body: some View {
//    Circle()
//      .foregroundColor(dark ? color.c500 : color.c100)
//      .size(small ? .s4 : .s5)
//      .shadow(
//        color: small ? color.c200 : color.c300,
//        radius: small ? .px : .s1,
//        x:  small ? .px : .s05,
//        y:  small ? .px : .s05
//      )
//      .overlay(
//        Text(number.string)
//          .font(small ? .caption2 : .caption)
//          .fontWeight(.bold)
//          .foregroundColor(dark ? color.c50 : color.c500)
//      )
//  }
//}


// TallyGoals/UI/toDo/Legacify/LegacyBehaviourCaroussel.swift
//import SwiftUI
//
//struct LegacyBehaviourCaroussel: View {
//  
//  let model: [Behaviour]
//  let store: AppStore
//  
//  var body: some View {
//    
//    if model.isEmpty {
//      EmptyView()
//    } else {
//      VStack {
//        
//        HStack {
//          
//          Spacer()
//          Text("See all")
//        }
//        .horizontal(24)
//        
//        HStack(spacing: 12) {
//          
//          ForEach(model) { item in
//            
//            LegacyBehaviourCard(
//              model: item, 
//              store: store
//            )
//              .leading(item == model.first ? 24 : 0)
//              .trailing(item == model.last ? 24 : 0)
//          }
//        }
//        .top(10)
//        .scrollify(.horizontal)
//      }
//    }
//  }
//}



// TallyGoals/UI/toDo/Legacify/LegacyBlinkinCard.swift
////
////  LegacyBlinkinCard.swift
////  TallyGoals
////
////  Created by Cristian Rojas on 03/06/2022.
////
//import ComposableArchitecture
//import CoreData
//import SwiftUI
//import SwiftWind
//
//struct CardView: View {
//
//  @GestureState var isPressing = false
//  @State var isAnimating = false
//  @State var isDialogPresented = false
//  @State var isScaling = false
//
//  let model: Behaviour
//  let store: AppStore
//
//  var body: some View {
//    WithViewStore(store) { viewStore in
//      Group {
//
//        ZStack {
//          
//          Card(
//            emoji: model.emoji,
//            name: model.name,
//            color: .blue,
//            behaviourId: model.id,
//            viewStore: viewStore,
//            showCount: true
//          )
//            .opacity(viewStore.state.isEditingPinned ? 0 : 1)
//            .opacity(isPressing ? 0.1 : 1)
//            .scaleEffect(isPressing ? 0.9 : 1)
//            .animation(.easeInOut(duration: 0.2).repeatCount(1, autoreverses: true), value: isPressing)
//            .highPriorityGesture(
//              TapGesture().onEnded {
//                viewStore.send(.addEntry(behaviour: model.id))
//              }
//            )
//            .simultaneousGesture(
//              LongPressGesture(minimumDuration: 0.8, maximumDistance: 1)
//                .updating($isPressing) { currentState, gestureState, transaction in
//                  gestureState = currentState
//                }
//                .onEnded { _ in
//
//                  withAnimation {
//                    viewStore.send(.startEditingPinned)
//                  }
//                }
//            )
//
//          if viewStore.state.isEditingPinned {
//            BlinkinCard(
//              model: model,
//              store: store
//            )
//          }
//        }
//      }
//    }
//  }
//
//  var regularComponent: some View {
//    VStack {
//
//      Rectangle()
//        .fill(Color(uiColor: .secondarySystemBackground))
//        .size(80)
//        .cornerRadius(12)
//        .overlay(
//          Text(model.emoji)
//        )
//
//      let name = model.name.count < 12 ? model.name + "\n" : model.name
//      Text(name)
//        .font(.caption2)
//        .multilineTextAlignment(.center)
//        .lineLimit(2)
//        .fixedSize(
//          horizontal: false,
//          vertical: true
//        )
//    }
//    .opacity(isPressing ? 0.05 : 1)
//
//  }
//
//  var blinkingComponent: some View {
//    regularComponent
//      .overlay(deleteButton, alignment: .topLeading)
//      .rotate(isAnimating ? 4 : 0)
//      .animation(
//        Animation.linear(duration: 0.1).repeatForever(),
//        value: isAnimating
//      )
//      .onAppear {
//        isAnimating = true
//      }
//  }
//
//  @ViewBuilder
//  var deleteButton: some View {
//    Circle()
//      .foregroundColor(.gray200)
//      .size(20)
//      .overlay(
//        Text("—")
//          .font(.caption)
//          .foregroundColor(.black)
//          .fontWeight(.bold)
//          .y(-1)
//      )
//      .x(-6)
//      .y(-6)
//      .onTapGesture {
//        isDialogPresented = true
//        print("Delete")
//      }
//  }
//
//}
//
//struct BlinkinCard: View {
//
//  @State var isAnimating = false
//  @State var isPresentingDialog = false
//  @State var showEditView = false
//  @State var showDeletingAlert = false
//
//  let model: Behaviour
//  let store: AppStore
//
//  var body: some View {
//
//    WithViewStore(store) { viewStore in
//      Card(
//        emoji: model.emoji,
//        name: model.name,
//        color: .gray,
//        behaviourId: model.id,
//        viewStore: viewStore,
//        showCount: false
//      )
//        .overlay(deleteButton, alignment: .topLeading)
//        .rotate(isAnimating ? 4 : 0)
//        .animation(
//          Animation.linear(duration: 0.1).repeatForever(),
//          value: isAnimating
//        )
////        .navigationLink(editScreen, $showEditView)
//        .onTap {
//          showEditView = true
//        }
//        .buttonStyle(.plain)
//        .onAppear {
//          isAnimating = true
//        }
//        .alert(isPresented: $showDeletingAlert) {
//          Alert(
//            title: Text("Are you sure you want to delete the item?"),
//            message: Text("This action cannot be undone"),
//            primaryButton: .destructive(Text("Delete"), action: { viewStore.send(.deleteBehaviour(id: model.id))}),
//            secondaryButton: .default(Text("Cancel"))
//          )
//        }
//        .confirmationDialog("Edit", isPresented: $isPresentingDialog, titleVisibility: .hidden) {
//          Button("Delete", role: .destructive) {
//            showDeletingAlert = true
//          }
//
//          Button("Unpin") {
//
//            withAnimation {
//              viewStore.send(.stopEditingPinned)
//              viewStore.send(.updatePinned(id: model.id, pinned: false))
//            }
//          }
//
//          Button("Archive") {
//            viewStore.send(.stopEditingPinned)
//            viewStore.send(.archive(id: model.id))
//          }
//        }
//    }
//  }
//
//
//  @ViewBuilder
//  var deleteButton: some View {
//    Circle()
//      .foregroundColor(.gray200)
//      .size(20)
//      .overlay(
//        Text("—")
//          .font(.caption)
//          .foregroundColor(.black)
//          .fontWeight(.bold)
//          .y(-1)
//      )
//      .x(-6)
//      .y(-6)
//      .onTapGesture {
//        //isEditing = false
//        isPresentingDialog = true
//        print("Delete")
//      }
//  }
//
////  var editScreen: some View {
////    BehaviourEditScreen(
////      store: store,
////      item: model,
////      emoji: model.emoji,
////      name: model.name
////    )
////  }
//
//}
//
//struct Card: View {
//
//  let emoji: String
//  let name: String
//  let color: WindColor
//  let behaviourId: NSManagedObjectID
//  let viewStore: AppViewStore
//  let showCount: Bool
//
//  var safeName: String {
//    name.count < 15 ? name + "\n" : name
//  }
//
//  var body: some View {
//
//    VStack {
//
//      Rectangle()
//        .fill(color.c100)
//        .size(80)
//        .cornerRadius(12)
//        .overlay(Text(emoji))
//        .overlay(badge(viewStore), alignment: .topTrailing)
//
////      Text(safeName)
////        .font(.caption2)
////        .multilineTextAlignment(.center)
////        .lineLimit(1)
////        .fixedSize(
////          horizontal: false,
////          vertical: true
////        )
//    }
//  }
//
//
//  func badge(_ viewStore: AppViewStore) -> some View {
//    Badge(number: 0, color: WindColor.blue)
//      .x(.s2)
//      .y(-.s2)
//      .displayIf(showCount)
//  }
//}
//
//extension View {
//  func rotate(_ angles: Double) -> some View {
//    self.rotationEffect(Angle(degrees: angles))
//  }
//}
//


// TallyGoals/UI/toDo/Legacify/ListRow.swift
//import CoreData
//import ComposableArchitecture
//import SwiftUI
//import SwiftUItilities
//import SwiftWind
//
//
//
//struct NewRow: View {
//  
//  let model: Behaviour
//  let color: WindColor
//  
//  var body: some View {
//    VStack {
//      HStack(alignment: .center) {
//        
//        Text("0")
//          .font(.title)
//          .fontWeight(.black)
//        
//        Text(model.emoji + " " + model.name)
//          .font(.caption)
//        
//        Spacer()
//        
//        Rectangle()
//          .foregroundColor(color.c800)
//          .size(36)
//          .overlay(Text("-"))
//          .cornerRadius(5)
//        //.trailing(12)
//        
//        Rectangle()
//          .foregroundColor(color.c800)
//          .size(36)
//          .overlay(Text("+"))
//          .cornerRadius(5)
//      }
//      .horizontal(24)
//      .vertical(12)
//      
//      Rectangle()
//        .foregroundColor(color.c700)
//        .height(1)
//    }
//    
//    .background(color.c900)
//  }
//}
//
//struct Row: View {
//  
//  @State var offset: CGFloat = .zero
//  @State var showEditScreen = false
//  @State var isEditing = false
//  
//  let model: Behaviour
//  let store: AppStore
//  
//  var body: some View {
//    WithViewStore(store) { viewStore in
//      DefaultVStack {
//        HStack {
//          Text(model.emoji)
//          Text(model.name)
//          Spacer()
//          Text(getCount(
//            behaviourId:model.id,
//            viewStore:viewStore
//          ))
//        }
//        .padding(10)
//        .background(Color(UIColor.systemBackground))
//        .offset(x: offset)
//        .simultaneousGesture(
//          LongPressGesture()
//            .onEnded { _ in
//              //showEditScreen = true
//              withAnimation {
//                isEditing.toggle()
//              }
//            }
//        )
//        .highPriorityGesture(
//          TapGesture()
//            .onEnded {
//              withAnimation {
//                
//                NotificationCenter.collapseRowList()
//                guard offset == 0 else {
//                  return
//                }
//                guard !isEditing else {
//                  isEditing = false
//                  return
//                }
//                viewStore.send(.addEntry(behaviour: model.id))
//              }
//            }
//        )
//        .background(
//          //                    DefaultHStack {
//          //
//          //
//          //                        SwipeActionView(
//          //                            tintColor: .yellow50,
//          //                            backColor: .yellow500,
//          //                            systemSymbol: "pin",
//          //                            offset: $offset
//          //                        ) {
//          //                            viewStore.send(
//          //                                .updatePinned(id: model.id, pinned: true)
//          //                            )
//          //                        }
//          //
//          //                        Spacer()
//          //
//          //                        SwipeActionView(
//          //                            tintColor: .orange50,
//          //                            backColor: .orange500,
//          //                            systemSymbol: "archivebox",
//          //                            offset: $offset
//          //                        ) {
//          //                            viewStore.send(.updateArchive(id: model.id, archive: true))
//          //                        }
//          //
//          //                        SwipeActionView(
//          //                            tintColor: .red50,
//          //                            backColor: .red700,
//          //                            systemSymbol: "trash",
//          //                            offset: $offset
//          //                        ) {
//          //                            viewStore.send(.deleteBehaviour(id: model.id))
//          //                        }
//          //                    }
//        )
//        .gesture(
//          DragGesture()
//            .onChanged { value in
//              
//              let width = value.translation.width
//              offset = width
//            }
//            .onEnded { value in
//              let width = value.translation.width
//              
//              if width > 1 {
//                withAnimation { offset = 40 }
//              } else if width < -80 {
//                withAnimation { offset = -80 }
//              } else if width < -40 {
//                withAnimation { offset = -40 }
//              } else {
//                withAnimation { offset = 0 }
//              }
//            }
//        )
//        
//        if isEditing {
//          
//          Rectangle()
//            .cornerRadius(8)
//            .height(80)
//            .horizontal(16)
//            .bottom(16)
//            .foregroundColor(.black)
//        }
//        
//        Divider()
//      }
//      .onReceive(NotificationCenter.collapseRowNotification) { _ in
//        guard offset != 0 else { return }
//        withAnimation { offset = 0 }
//      }
//      //            .navigationLink(
//      //                editScreen,
//      //                $showEditScreen
//      //            )
//    }
//    
//  }
//  
//  //    var editScreen: some View {
//  //        BehaviourEditScreen(
//  //            store: store,
//  //            item: model,
//  //            emoji: model.emoji,
//  //            name: model.name
//  //        )
//  //    }
//  //
//
//}
//
//
//struct ListRow: View {
//  
//  @State var showDetail = false
//  let store: AppStore
//  let item: Behaviour
//  let archive: Bool
//  
//  init(
//    store: AppStore,
//    item: Behaviour,
//    archive: Bool = false
//  ) {
//    self.store = store
//    self.item = item
//    self.archive = archive
//  }
//  
//  var body: some View {
//    WithViewStore(store) { viewStore in
//      HStack {
//        
//        //if !archive {
//        Rectangle()
//          .width(2)
//          .foregroundColor(color)
//        //Image(systemName: item.favorite ? "star.fill" : "star")
//        //.resizable()
//        //.size(10)
//        //.foregroundColor(item.favorite ? .yellow : .gray)
//        //.opacity(item.favorite ? 1 : 0.2)
//        
//        //}
//        
//        Text(item.emoji)
//          .grayscale(archive ? 1 : 0)
//        Text(item.name)
//        
//        Spacer()
//        
//        let count = getCount(
//          behaviourId: item.id,
//          viewStore: viewStore
//        )
//        
//        Text(count.string)
//      }
//      //            .background(detailLinkTwo)
//      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12))
//      .onTapGesture {
//        withAnimation {
//          if viewStore.adding {
//            viewStore.send(
//              .addEntry( behaviour: item.id)
//            )
//          } else {
//            viewStore.send(
//              .deleteEntry(behaviour: item.id)
//            )
//          }
//        }
//      }
//      .onLongPressGesture {
//        print("longpress")
//        showDetail = true
//      }
//    }
//  }
//  
//  
//  var color: Color {
//    item.pinned
//    ? .indigo : .clear
//  }
//  
//  var testLink: some View {
//    Text("link")
//  }
//  //
//  //    var detailLink: some View {
//  //        EmptyNavigationLink(
//  //            destination: editScreen,
//  //            isActive: $showDetail
//  //        )
//  //            .disabled(true)
//  //    }
//  //
//  //    var editScreen: some View {
//  //        BehaviourEditScreen(
//  //            store: store,
//  //            item: item,
//  //            emoji: item.emoji,
//  //            name: item.name
//  //        )
//  //    }
//  //
//  //    var detailLinkTwo: some View {
//  //        NavigationLink(destination: editScreen, isActive: $showDetail) {
//  //            EmptyView()
//  //        }
//  //        .hidden()
//  //        .buttonStyle(PlainButtonStyle())
//  //        .disabled(true)
//  //    }
//  
//}
//
//


// TallyGoals/UI/toDo/Legacify/SequenceCard.swift
//
//  SequenceCard.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 14/06/2022.
//

import SwiftUI

struct SequenceCard: View {
  
  @GestureState var isPressing = false
  @State var translation: CGSize = .zero
  @State var width: CGFloat = .zero
  
  var body: some View {
    VStack {
      
      Color(uiColor: .secondarySystemBackground)
        .aspectRatio(312/500, contentMode: .fit)
        .cornerRadius(24)
        .overlay(
          VStack() {
            Text("👔")
              .font(.largeTitle)
            Text("x1")
              .font(.caption)
            
            Text("Planchar ropa título largo dfdfdfdfddf")
              .multilineTextAlignment(.center)
              .font(.body)
              .top(12)
          }
        )
        .overlay(
          HStack(spacing: 24) {
            Image(systemName: isPressing ? "x.circle.fill" : "x.circle")
              .resizable()
              .size(40)
              .foregroundColor(.red)
              .scaleEffect(isPressing ? 0.8 : 1)
              .animation(.easeInOut(duration: 0.15), value: isPressing)
              .highPriorityGesture(
                TapGesture()
                  .onEnded { _ in
                    print("did tap")
                  }
              )
              .simultaneousGesture(
                LongPressGesture()
                  .updating($isPressing) { currentState, gestureState, transaction in
                    gestureState = currentState
                  }
                  .onEnded { _ in
                    print("Ended")
                  }
              )
            
            Image(systemName: "checkmark.circle")
              .resizable()
              .size(40)
              .foregroundColor(.green)
          }
            .y(-20)
          , alignment: .bottom
        )
        .horizontal(24)
        .x(translation.width)
        .y(translation.height)
        .rotationEffect(.degrees(translation.width / 200) * 25, anchor: .bottom)
        .gesture(
          DragGesture()
            .onChanged { value in
              translation = value.translation
            }
            .onEnded { _ in
              withAnimation {
                translation = .zero
              }
            }
        )
      
      
      
    }
  }
}


// TallyGoals/UI/toDo/Legacify/ShakeEffect.swift
//
//  ShakeEffect.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 29/05/2022.
//

import SwiftUI

struct ShakeEffect: GeometryEffect {
  
  var animatableData: CGFloat
  
  private let const: CGFloat = .s2
  func modifier(_ x: CGFloat) -> CGFloat {
    const * sin(x * .pi * 2)
  }
  
  func effectValue(size: CGSize) -> ProjectionTransform {
    let transform = ProjectionTransform(CGAffineTransform(translationX: const + modifier(animatableData), y: 0))
    return transform
  }
}


// TallyGoals/UI/toDo/Modularize/SwipeActions/Manager.swift
//
//  Manager.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import Combine
import SwiftUI

final class SwipeManager: ObservableObject {
  
  @Published var swipingId: UUID?
  @Published var rowIsOpened: Bool = false
  
  var cancellables = Set<AnyCancellable>()
  
  static let shared = SwipeManager()
  private init() {}
  
  func collapse() {
    rowIsOpened = false
  }
}


// TallyGoals/UI/toDo/Modularize/SwipeActions/Regular/SwipeActionModifier.swift
//
//  SwipeActionModifier.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI
import Combine
import SwiftUItilities

struct SwipeActionModifier: ViewModifier {
  
  @State var offset = CGFloat.zero
  
  private let id = UUID()
  let leading: [SwipeAction]
  let trailing: [SwipeAction]
 
  /// Sends current item id to the manager
  /// This allows to collapse all the non-current row actions
  func sink() {
    SwipeManager.shared.$swipingId.dropFirst().sink { swipingId in
      guard let swipingId = swipingId else {
        resetOffset()
//        SwipeManager.shared.collapse()
        return
      }
      if id != swipingId {
        resetOffset()
      }
    }
    .store(in: &SwipeManager.shared.cancellables)
    
    SwipeManager.shared.$rowIsOpened.dropFirst().sink { isOpened in
      if !isOpened {
        resetOffset()
      }
    }
    .store(in: &SwipeManager.shared.cancellables)
  }
  
  func body(content: Content) -> some View {
    
    content
      .onAppear(perform: sink)
      .background(content)
      .x(offset)
      .background(actions)
      .simultaneousGesture(
        DragGesture()
          .onChanged(onChangedEvent)
          .onEnded(onEndedEvent)
      )
  }
  
  var actions: some View {
    DefaultHStack {
      
      leadingActions
      trailingActions
    }
  }
  
  var totalLeadingWidth: CGFloat {
      .swipeActionItemWidth * leading.count
  }
  
  var leadingActions: some View {
   ZStack(alignment: .leading) {
     ForEach(leading.reversed().indices, id: \.self) { index in
        let action = leading.reversed()[index]
        let realIndex = leading.firstIndex(of: action)!
        let factor = (realIndex + 1).cgFloat
        let width = .swipeActionItemWidth * factor
        let dynamicWidth = offset / leading.count * factor
        let maxWidth = dynamicWidth < width ? dynamicWidth : width
        let shouldExpand = offset > totalLeadingWidth && realIndex == 0
        
        let callback = {
          action.action()
          resetOffset()
        }
        
        SwipeActionView(
          width: maxWidth,
          action: action,
          callback: callback
        )
        .width(shouldExpand ? totalLeadingWidth : maxWidth)
      }
    }
    .alignX(.leading)
    .displayIf(leading.isNotEmpty)
  }
  
  func actionView(_ action: SwipeAction, width: CGFloat) -> some View {
    let iconWidth = CGFloat.s4
    let iconOffset = (.swipeActionItemWidth - iconWidth) / 2
    return action.backgroundColor
      .overlay(
        Image(systemName: "action.systemSymbol")
          .resizable()
          .foregroundColor(.red)
          .size(iconWidth)
          .x(-iconOffset)
          
        ,
        alignment: .trailing
      )
  }
  
  var trailingActions: some View {
    HStack {
      Spacer()
      Text("Trailing")
    }
    .displayIf(trailing.isNotEmpty)
  }
  
  func resetOffset() {
    // .timingCurve(0.5, 0.5, 0.8, 0.7
    withAnimation(.easeOut(duration: 0.45)) { offset = .zero }
  }
  
  var isOpened: Bool { offset >= totalLeadingWidth }
  
  @State private var shouldHapticFeedback: Bool = true
  @State private var shouldSendId: Bool = true
  
  func onChangedEvent(_ value: DragGesture.Value) {
    
    let width = value.translation.width
    if shouldSendId {
    SwipeManager.shared.swipingId = id
      shouldSendId = false
    }
    guard !isOpened else {
//      print("isOpened")
      if offset > totalLeadingWidth && shouldHapticFeedback {
      NotificationFeedback.shared.notificationOccurred(.success)
        shouldHapticFeedback = false
      }
      let maxAddOffset = width < .s2 ? width : .s2
      withAnimation { offset = totalLeadingWidth + maxAddOffset }
      
      
      return
    }
    
    withAnimation {
//      print("Modifiying offset...")
      offset = width
    }
  }
  
  func onEndedEvent(_ value: DragGesture.Value) {
    
    let width = value.translation.width
    
    shouldHapticFeedback = true
    shouldSendId = true
   
    
    guard leading.isNotEmpty else {
     return
    }
    
    
    if isOpened && (offset + width) > totalLeadingWidth {
      leading.first?.action()
    }
    
      if width > .s28 && width < totalLeadingWidth {
        withAnimation {
          offset = totalLeadingWidth
          SwipeManager.shared.rowIsOpened = true
        }
      } else if width > totalLeadingWidth {
        leading.first?.action()
        resetOffset()
        SwipeManager.shared.rowIsOpened = false
      } else {
        resetOffset()
        SwipeManager.shared.rowIsOpened = false
      }

  }
}


// TallyGoals/UI/toDo/Modularize/SwipeActions/Regular/SwipeActions.swift
//
//  SwipeActions.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 02/06/2022.
//
import SwiftUI
import SwiftUItilities

struct SwipeAction: Identifiable, Equatable {

  let id: UUID = UUID()
  let label: String?
  let systemSymbol: String
  let action: () -> Void
  let backgroundColor: Color
  let tintColor: Color
  
  init(
    label: String?,
    systemSymbol: String,
    action: @escaping () -> Void,
    backgroundColor: Color = .black,
    tintColor: Color = .white
  ) {
    self.label = label
    self.systemSymbol = systemSymbol
    self.action = action
    self.backgroundColor = backgroundColor
    self.tintColor = tintColor
  }
  
  static func == (
    lhs: SwipeAction,
    rhs: SwipeAction
  ) -> Bool {
    lhs.id == rhs.id
  }
}

extension CGFloat {
  static let swipeActionItemWidth = CGFloat.s1 * 18
}

extension View {

  func swipeActions(
    leading: [SwipeAction] = [],
    trailing: [SwipeAction] = []
  ) -> some View {
    
    self.modifier(
      SwipeActionModifier(
        leading: leading,
        trailing: trailing
      )
    )
  }
}



// TallyGoals/UI/toDo/Modularize/SwipeActions/Regular/SwipeActionsView.swift
//
//  SwipeActionsView.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 29/05/2022.
//

import SwiftUI
import SwiftWind

struct SwipeActionView: View {
  
  @State var width: CGFloat
  let action: SwipeAction
  let callback: () -> Void
  private var iconOffset: CGFloat { (.swipeActionItemWidth - width) / 2 }
 
  var body: some View {
    return action.backgroundColor
      .overlay(
        Image(systemName: action.systemSymbol)
          .foregroundColor(action.tintColor)
          .bindWidth(to: $width)
          .x(-iconOffset)
        ,
        alignment: .trailing
      )
      .onTap(perform: callback)
      .buttonStyle(.plain)
  }
}


// TallyGoals/UI/toDo/Modularize/SwipeActions/Spark/SparkSwipeActionModifier.swift
//
//  SparkSwipeActionModifier.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI

struct SparkSwipeActionModifier: ViewModifier {
  
  @State var width = CGFloat.zero
  @State var offset = CGFloat.zero
  @State var currentLeadingIndex = Int.zero
  @State var currentTrailingIndex = Int.zero
  @State var shouldHapticFeedback = true
  
  let leading: [SwipeAction]
  let trailing: [SwipeAction]
  
  func body(content: Content) -> some View {
    content
    .bindWidth(to: $width)
    .x(offset)
    .background(leadingGestures)
    .background(trailingGestures)
    .onChange(of: currentLeadingIndex, perform: handleIndexChange(_:))
    .onChange(of: currentTrailingIndex, perform: handleIndexChange(_:))
    .gesture(drag)
  }
  
  func handleIndexChange(_ index: Int) {
    guard index > 0 else { return }
    UIImpactFeedbackGenerator.shared.impactOccurred()
    
    #if DEBUG
    print("index changed: \(index)")
    #endif
  }
  
  @ViewBuilder
  var leadingGestures: some View {

    if leading.isEmpty {
      EmptyView()
    } else {
      
      let initOffset = -.s6 + offset
      let treasholdReached = initOffset > .s3
      
      ZStack {
        ForEach(0...leading.count - 1) { index in
          let isCurrent = index == currentLeadingIndex
          let item = leading[index]
          item.backgroundColor
            .opacity(treasholdReached ? 1 : 0)
            .opacity(isCurrent ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isCurrent)
        }
        .overlay(leadingGestureLabels, alignment: .leading)
      }
    }
  }
  
  @ViewBuilder
  var trailingGestures: some View {
   
    if trailing.isEmpty {
      EmptyView()
    } else {
      
      
      let initOffset = .s6 + offset
      let treasholdReached = initOffset < -.s3
      
      ZStack {
        ForEach(0...trailing.count - 1) { index in
          let isCurrent = index == currentTrailingIndex
          let item = trailing[index]
          item.backgroundColor
          .opacity(treasholdReached ? 1 : 0)
          .opacity(isCurrent ? 1 : 0)
          .animation(.easeInOut(duration: 0.3), value: isCurrent)
        }
        .overlay(trailingGestureLabels, alignment: .trailing)
      }
    }
  }
  
  @ViewBuilder
  var trailingGestureLabels: some View {
    let initOffset = .s6 + offset
    let treasholdReached = initOffset < -.s3
    let item = trailing.getOrNil(index: currentTrailingIndex)
    
    if let item = item {
      HStack {
        
        if let label =  item.label {
          Text(label)
            .opacity(treasholdReached ? 1 : 0)
        }
        
        Image(systemName: item.systemSymbol)
        
      }
      .foregroundColor(item.tintColor)
      .x(treasholdReached ? -.s3 : initOffset)
    } else {
      EmptyView()
    }
  }
  
  @ViewBuilder
  var leadingGestureLabels: some View {
    let initOffset = -.s6 + offset
    let treasholdReached = initOffset > .s3
    let item = leading.getOrNil(index: currentLeadingIndex)
    
    if let item = item {
      HStack {
        
        Image(systemName: item.systemSymbol)
        if let label =  item.label {
          Text(label)
            .opacity(treasholdReached ? 1 : 0)
        }
      }
      .foregroundColor(item.tintColor)
      .x(treasholdReached ? .s3 : initOffset)
    } else {
      EmptyView()
    }
  }
  
  var drag: some Gesture {
    DragGesture()
    .onChanged(handleDragChange)
    .onEnded(handleDragEnd)
  }
  
  func handleDragChange(_ value: DragGesture.Value) {
    
    let horizontalTranslation = value.translation.width
    
    if horizontalTranslation > .s8 && shouldHapticFeedback {
      UIImpactFeedbackGenerator.shared.impactOccurred()
      shouldHapticFeedback = false
    }
    
    if horizontalTranslation < -.s8 && shouldHapticFeedback {
      UIImpactFeedbackGenerator.shared.impactOccurred()
      shouldHapticFeedback = false
    }
    
    withAnimation {
      offset = horizontalTranslation
    }
    
    let factor = horizontalTranslation / width
    
    currentLeadingIndex = Int(factor * leading.count)
    
    if horizontalTranslation < 0 {
      currentTrailingIndex = abs(Int(factor * trailing.count))
      print(currentTrailingIndex)
    }
  }
  
  func handleDragEnd(_ value: DragGesture.Value) {
    
    let horizontalTranslation = value.translation.width
    
    shouldHapticFeedback = true
    
    if horizontalTranslation >= .s12 {
      leading.getOrNil(index: currentLeadingIndex)?.action()
    }
    
    if horizontalTranslation <= -.s12 {
      trailing.getOrNil(index: currentTrailingIndex)?.action()
    }
    
    resetOffset()
  }
  
  func resetIndex() {
    withAnimation { currentLeadingIndex = 0 }
  }
  
  func resetOffset() {
    withAnimation { offset = 0 }
  }
}


// TallyGoals/UI/toDo/Modularize/SwipeActions/Spark/View+sparkSwipeActions.swift
//
//  View+sparkSwipeActions.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI

extension View {
  func sparkSwipeActions(
    leading: [SwipeAction] = [],
    trailing: [SwipeAction] = []
  ) -> some View {
    self.modifier(SparkSwipeActionModifier(leading: leading, trailing: trailing))
  }
}


// TallyGoals/UI/toDo/Modularize/VerticalLinearGradient.swift
//
//  VerticalLinearGradient.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI

struct VerticalLinearGradient: View {
  let colors: [Color]
  var body: some View {
    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}


// TallyGoals/UI/toDo/Modularize/WindColors.swift
//
//  WindColors.swift
//  TallyGoals
//
//  Created by Cristian Rojas on 03/06/2022.
//

import SwiftUI
import SwiftWind

/// Enum allows iteration for demo purposes (showing all colors)
/// This will replace the WindColor struct on SwiftWind on a future release
enum WindColors: Int, CaseIterable {
  case slate
  case gray
  case zinc
  case neutral
  case stone
  case red
  case orange
  case yellow
  case lime
  case green
  case emerald
  case teal
  case cyan
  case sky
  case blue
  case indigo
  case violet
  case amber
  case purple
  case fuchsia
  case pink
  case rose

  
  var color: WindColor {
    switch self {
      
    case .amber:
      return .amber
    case .purple:
      return .purple
    case .slate:
      return .slate
    case .gray:
      return .gray
    case .zinc:
      return .zinc
    case .neutral:
      return .neutral
    case .stone:
      return .stone
    case .red:
      return .red
    case .orange:
      return .orange
    case .yellow:
      return .yellow
    case .lime:
      return .lime
    case .green:
      return .green
    case .emerald:
      return .emerald
    case .teal:
      return .teal
    case .cyan:
      return .cyan
    case .sky:
      return .sky
    case .blue:
      return .blue
    case .indigo:
      return .indigo
    case .violet:
      return .violet
    case .fuchsia:
      return .fuchsia
    case .pink:
      return .pink
    case .rose:
      return .rose
    }
  }
  
  var t50: Color {
    switch self {
    case .slate:
      return .slate50
    case .gray:
      return .gray50
    case .zinc:
      return .zinc50
    case .neutral:
      return .neutral50
    case .stone:
      return .stone50
    case .red:
      return .red50
    case .orange:
      return .orange50
    case .yellow:
      return .yellow50
    case .lime:
      return .lime50
    case .green:
      return .green50
    case .emerald:
      return .emerald50
    case .teal:
      return .teal50
    case .cyan:
      return .cyan50
    case .sky:
      return .sky50
    case .blue:
      return .blue50
    case .indigo:
      return .indigo50
    case .violet:
      return .violet50
    case .amber:
      return .amber50
    case .purple:
      return .purple50
    case .fuchsia:
      return .fuchsia50
    case .pink:
      return .pink50
    case .rose:
      return .rose50
    }
  }
}


// TallyGoalsTests/BehaviourRepositoryActions.swift
//
//  TallyGoalsTests.swift
//  TallyGoalsTests
//
//  Created by Cristian Rojas on 27/05/2022.
//
//import ComposableArchitectureTestSupport
import ComposableArchitecture
import XCTest
@testable import TallyGoals


/// **Behaviour Repository:**
/// - Tests each action of the architecture related to the Behaviour Repository
/// - Indirectly test their implementations by the reducer.
/// - Indirectly test CoreData by using a inMemory viewContext
class BehaviourRepositoryTests: XCTestCase {
  
  var environment: AppEnvironment!
  
  override func setUpWithError() throws {
    
    /// Set environment on each test
    let inMemoryContext = PersistenceController(inMemory: true).container.viewContext
    let repository = BehaviourRepository(context: inMemoryContext)
    environment = AppEnvironment(behavioursRepository: repository)
  }
  
  override func tearDownWithError() throws {
    /// Reset environment on each test
    environment = nil
  }
  
  /// When fetching the database on first time, we should get an empty state (no behaviours)
  func testReadBehavioursOnFirstLaunch() {
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    /// If we send the readBehaviours action,
    /// That should mutate behaviourState from 'idle' to loading
    store.send(.readBehaviours) {
      $0.behaviourState = .loading
    }
    
    /// Then, once the databaseFetched, we should:
    /// - Receive an makeBehaviourState action
    /// - Get an empty behaviourState
    store.receive(.makeBehaviourState(.empty)) {
      $0.behaviourState = .empty
    }
  }
  
  func testCreateBehaviour() {
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    let id = UUID()
    let emoji = "💧"
    let name = "Testing"
    
    let expectedBehaviours = [Behaviour(
      id: id,
      emoji: emoji,
      name: name,
      count: 0
    )]
    
    let expectedBehaviourState: BehaviourState = .success(expectedBehaviours)
    
    store.send(.createBehaviour(id: id, emoji: emoji, name: name))
    
    wait()
    
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    
    store.receive(.makeBehaviourState(expectedBehaviourState)) {
      $0.behaviourState = expectedBehaviourState
    }
  }
  
  func testUpdateFavorite() {
    updateBehaviour(action: .favorite)
  }
  
  func testUpdatePinned() {
    updateBehaviour(action: .pin)
  }
  
  func testUpdateArchive() {
    updateBehaviour(action: .archive)
  }
  
  func testUpdateBehaviourMetaData() {
    var behaviour = Behaviour(
      id: UUID(),
      emoji: "🙂",
      name: "Be happy",
      count: 0
    )
    
    var expectedState = BehaviourState.success([behaviour])
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    // MARK: - Create the behaviour
    store.send(.createBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    
    wait()
    
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
    
    
    /// Updated behaviour
    behaviour = Behaviour(
      id: behaviour.id,
      emoji: "🙂",
      name: "New name",
      count: behaviour.count
    )
    
    expectedState = .success([behaviour])
    
    
    store.send(.updateBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    
    wait()
    
    store.receive(.readBehaviours) { $0.behaviourState = .loading }
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
  }
  
  func testDeleteBehaviour() {
    let behaviour = Behaviour(
      id: UUID(),
      emoji: "🙂",
      name: "Be happy",
      count: 0
    )
    
    let expectedFirstState = BehaviourState.success([behaviour])
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    store.send(.createBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    
    wait()
    
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    
    store.receive(.makeBehaviourState(expectedFirstState)) {
      $0.behaviourState = expectedFirstState
    }
    
    store.send(.deleteBehaviour(id: behaviour.id))
    
    wait()
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    store.receive(.makeBehaviourState(.empty)) {
      $0.behaviourState = .empty
    }
  }
  
  func testAddEntry() {
    var behaviour = Behaviour(
      id: UUID(),
      emoji: "🙂",
      name: "Be happy",
      count: 0
    )
    
    var expectedState = BehaviourState.success([behaviour])
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    store.send(.createBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    
    wait(timeout: 0.05)
    
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
    
    behaviour.count += 1
    expectedState = .success([behaviour])
    
    store.send(.addEntry(behaviour: behaviour.id))
    
    wait()
    
    store.receive(.readBehaviours) { $0.behaviourState = .loading}
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
  }
  
  func testDeleteEntry() {
    var behaviour = Behaviour(
      id: UUID(),
      emoji: "🙂",
      name: "Be happy",
      count: 0
    )
    
    var expectedState = BehaviourState.success([behaviour])
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    store.send(.createBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    wait()
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
    
    behaviour.count += 1
    expectedState = .success([behaviour])
    
    store.send(.addEntry(behaviour: behaviour.id))
    wait()
    store.receive(.readBehaviours) { $0.behaviourState = .loading}
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
    
    behaviour.count -= 1
    expectedState = .success([behaviour])
    
    store.send(.deleteEntry(behaviour: behaviour.id))
    wait()
    store.receive(.readBehaviours) { $0.behaviourState = .loading }
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
  }
  
  private enum UpdateAction {
    case favorite
    case archive
    case pin
  }
  
  private func updateBehaviour(action: UpdateAction) {
    
    var behaviour = Behaviour(
      id: UUID(),
      emoji: "🙂",
      name: "Be happy",
      count: 0
    )
    
    var expectedState = BehaviourState.success([behaviour])
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )
    
    store.send(.createBehaviour(
      id: behaviour.id,
      emoji: behaviour.emoji,
      name: behaviour.name
    ))
    
    wait()
    
    store.receive(.readBehaviours) {
      $0.behaviourState = .loading
    }
    
    store.receive(.makeBehaviourState(expectedState)) {
      $0.behaviourState = expectedState
    }
    
    
    switch action {
    case .favorite:
      behaviour.favorite = true
      expectedState = BehaviourState.success([behaviour])
      
      store.send(.updateFavorite(id: behaviour.id, favorite: true))
      wait()
      store.receive(.readBehaviours) {
        $0.behaviourState = .loading
      }
      store.receive(.makeBehaviourState(expectedState)) {
        $0.behaviourState = expectedState
      }
    case .archive:
      behaviour.archived = true
      expectedState = BehaviourState.success([behaviour])
      
      store.send(.updateArchive(id: behaviour.id, archive: true))
      wait()
      store.receive(.readBehaviours) {
        $0.behaviourState = .loading
      }
      store.receive(.makeBehaviourState(expectedState)) {
        $0.behaviourState = expectedState
      }
    case .pin:
      behaviour.pinned = true
      expectedState = BehaviourState.success([behaviour])
      
      store.send(.updatePinned(id: behaviour.id, pinned: true))
      wait()
      store.receive(.readBehaviours) {
        $0.behaviourState = .loading
      }
      store.receive(.makeBehaviourState(expectedState)) {
        $0.behaviourState = expectedState
      }
    }
  }
  
  /// If test fail with the following error:
  /// _"An effect returned for this action is still running. It must complete before the end of the test"_.
  /// That means, that specific test needs some more time in order to wait for the returned action to finish running,
  /// If that's the case you could override the default timeout (time to wait) argument by incrementing it a little
  private func wait(timeout: Double = 0.001) {
    _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: timeout)
  }
  
}


// TallyGoalsTests/OtherStateActionsTests.swift
//
//  OtherStateActionsTests.swift
//  TallyGoalsTests
//
//  Created by Cristian Rojas on 25/06/2022.
//
import ComposableArchitecture
import XCTest
@testable import TallyGoals

/*
 
 Tests the overlay manager on state
 */

class OtherStateActionsTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

  func testSetOverlay() {
    
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(behavioursRepository: BehaviourRepository(context: PersistenceController.preview.container.viewContext))
    )
    
    let presetCategory = PresetCategory(
      emoji: "💧",
      name: "Mental clarity"
    )
    
    let overlayModel = Overlay.exploreDetail(presetCategory)
    
    store.send(.setOverlay(overlay: overlayModel)) {
      $0.overlay = overlayModel
    }
  }

}



// p2-rpg.swift

// rpg/main.swift
/*
 
main.swift


 
 /$$$$$$$  /$$$$$$$   /$$$$$$  /$$      /$$                 /$$
 | $$__  $$| $$__  $$ /$$__  $$| $$$    /$$$                | $$
 | $$  \ $$| $$  \ $$| $$  \__/| $$$$  /$$$$  /$$$$$$   /$$$$$$$ /$$$$$$$   /$$$$$$   /$$$$$$$ /$$$$$$$
 | $$$$$$$/| $$$$$$$/| $$ /$$$$| $$ $$/$$ $$ |____  $$ /$$__  $$| $$__  $$ /$$__  $$ /$$_____//$$_____/
 | $$__  $$| $$____/ | $$|_  $$| $$  $$$| $$  /$$$$$$$| $$  | $$| $$  \ $$| $$$$$$$$|  $$$$$$|  $$$$$$
 | $$  \ $$| $$      | $$  \ $$| $$\  $ | $$ /$$__  $$| $$  | $$| $$  | $$| $$_____/ \____  $$\____  $$
 | $$  | $$| $$      |  $$$$$$/| $$ \/  | $$|  $$$$$$$|  $$$$$$$| $$  | $$|  $$$$$$$ /$$$$$$$//$$$$$$$/
 |__/  |__/|__/       \______/ |__/     |__/ \_______/ \_______/|__/  |__/ \_______/|_______/|_______/
                                                                                                       
 
 */



import Foundation

let game = Game()
game.start()


// rpg/Model/Character.swift
//
//  Character.swift
//  rpg
//
//  Created by Cristian Rojas on 15/07/2020.
//  MIT 
//

import Foundation

class Character {
    
    /// Defines the character's name as an empty string. It will be defined later on
    var name : String = ""
    /// Defines the health of the Character
    var health : Int
    /// Creates a weapon for the character
    var weapon : Weapon
    /// Defines the emoji of the character
    var emoji : String
    /// Defines the healing power
    var healingPower : Int
    
    
    init(health: Int, weapon: Weapon, emoji: String, healingPower: Int) {
        
        self.health = health
        self.weapon = weapon
        self.emoji = emoji
        self.healingPower = healingPower
        
    }
    
    convenience init() { self.init(health: 100, weapon: Weapon(), emoji: "👤", healingPower: 10) }
    
    /// Heal a team member
    func healComrade(character: Character) { character.health += healingPower }
    /// Attack a member of the other team
    func attackEnemy(character: Character) { character.receiveDamage(damage: weapon.power) }
    
    /// Receive's damage if attacked by the enemy
    func receiveDamage(damage: Int) {
        health -= damage
        health = health < 0 ? 0 : health
    }
    
}

// PROTOCOLS AND HELPERS

extension Character: Equatable {
    /// Allows to distinguish characters
    static func ==(firstCharacter: Character, secondCharacter: Character) -> Bool {
        return firstCharacter.name == secondCharacter.name
    }
    /// Checks if a character is dead
    func isDead() -> Bool { return health <= 0 }
}


// rpg/Model/Characters/Archer.swift
//
//  Archer.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Archer : Character {
    
    init() {
        super.init(health: 100, weapon: Arc(), emoji: "🏹", healingPower: 15)
    }
}


// rpg/Model/Characters/Knight.swift
//
//  Knight.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Knight : Character {
    
    init() {
        super.init(health: 130, weapon: Sword(), emoji: "🗡", healingPower: 10)
    }
}


// rpg/Model/Characters/Magician.swift
//
//  Magician.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Magician : Character {
    
    init() {
        super.init(health: 60, weapon: Wand(), emoji: "🧙🏻‍♂️", healingPower: 35)
    }
}


// rpg/Model/Game.swift
//
//  Game.swift
//  rpg
//
//  Created by Cristian Rojas on 16/07/2020.
//  MIT
//

import Foundation

class Game {
    /// Stores the players
    var players = [Player(), Player()]
    /// Creates an object "text" with all the text that we will print to the user
    var text = Text()
    /// Stores the number of characters per team (in the array player.team)
    var numberOfCharacters = 3
    /// Start the game
    func start() {
        
        text.setLang()
        welcome()
        //chooseCharacterNumber()
        namingPlayers()
        play()
        gameStats()
        restart()
    }
    
    /// Allows user to choose the number of characters and limits his choice to a choosen range
    func chooseCharacterNumber() { numberOfCharacters = Utilities.waitForInput(message: text.chooseNumberOfCharacters, condition: 2...10) }
    
    /// Welcomes the user and prints the game's logo
    func welcome() {
        print("\(text.welcome)\n\n")
        print("  /$$$$$$$  /$$$$$$$   /$$$$$$  /$$      /$$                 /$$\n | $$__  $$| $$__  $$ /$$__  $$| $$$    /$$$                | $$\n | $$  \\ $$| $$  \\ $$| $$  \\__/| $$$$  /$$$$  /$$$$$$   /$$$$$$$ /$$$$$$$   /$$$$$$   /$$$$$$$ /$$$$$$$\n | $$$$$$$/| $$$$$$$/| $$ /$$$$| $$ $$/$$ $$ |____  $$ /$$__  $$| $$__  $$ /$$__  $$ /$$_____//$$_____/\n | $$__  $$| $$____/ | $$|_  $$| $$  $$$| $$  /$$$$$$$| $$  | $$| $$  \\ $$| $$$$$$$$|  $$$$$$|  $$$$$$\n | $$  \\ $$| $$      | $$  \\ $$| $$\\  $ | $$ /$$__  $$| $$  | $$| $$  | $$| $$_____/ \\____  $$\\____  $$\n | $$  | $$| $$      |  $$$$$$/| $$ \\/  | $$|  $$$$$$$|  $$$$$$$| $$  | $$|  $$$$$$$ /$$$$$$$//$$$$$$$/\n |__/  |__/|__/       \\______/ |__/     |__/ \\_______/ \\_______/|__/  |__/ \\_______/|_______/|_______/\n\n")
    }
    
    /// Creates the players and his team
    func namingPlayers() {
        
        for i in 0..<players.count {
            var name = ""
            repeat {
                print("👤 Player \(i+1), \(text.chooseYourName)")
                name = readLine()!.normalize()
            } while name.isBlank
            
            players[i].name = name
            players[i].createCharacters()
            
        }
    }
    
    /// Made players chose their moves in alternating turns
    func play() {
        while players[0].teamIsDead() == false && players[1].teamIsDead() == false {
            players[0].move(against: players[1])
            players[0].count += 1
            if players[1].teamIsDead() == false {
                players[1].move(against: players[0])
                players[1].count += 1
            }
        }
    }
    
    /// Shows information about the winner (name, characters alive...) and the number of movements of both players
    func gameStats() {
        
        for player in players {
            if player.teamHealth > 0 {
                print("🔥🔥🔥🔥🔥")
                print("\(player.name) \(text.won) 💪!")
                print("\(player.team.count) \(text.leftoutof) \(numberOfCharacters): ")
                for character in player.team {
                    print("\(character.name) 💉: \(character.health) + 💪: \(character.weapon.power)")
                }
                
            }
            print("\(player.name): \(player.count) \(text.movements)") 
            
        }
    }
    
    /// Allows the user to choose wether restart the game or not at the end of a match
    func restart() {
        var choice = ""
        repeat {
            print("Restart y/n")
            choice = readLine()!
        } while choice != "y" && choice != "n"
        
        if choice == "y" { reset() ; start() } else { return }
    }
    
    ///Resets the game by removing the old players
    func reset() { players.removeAll() ; players = [Player(), Player()] }
}


// rpg/Model/Player.swift
//
//  Player.swift
//  rpg
//
//  Created by Cristian Rojas on 15/07/2020.
//  MIT
//

import Foundation

class Player {
    /// Player's name. Declared empty becasue we well use game.namingPlayers()
    var name = ""
    /// Array that contains the members of the team
    var team = [Character]()
    /// Creates a count variable we'll update with every move of the player
    var count = Int()
    /// Returns the total health of the team.
    var teamHealth : Int {
        var total : Int = Int()
        for character in team {
            total += character.health
        }
        return total
    }
    
    /// Checks if all the team members are dead
    func teamIsDead() -> Bool {
        return teamHealth == 0
    }
    /// Creates the caracter's inside the player.team array
    func createCharacters() {
        
        // Creates characters and appends them to the array "team"
        while team.count < game.numberOfCharacters {
            let message = "\n\n\(name), \(game.text.chooseKind) \(team.count + 1)\n"
                + "\n1.\n🗡 \(game.text.knight)\n💉: 130. 💪: 35. 👨‍⚕️: 10"
                + "\n2.\n🏹 \(game.text.archer)\n💉: 100. 💪: 60. 👨‍⚕️: 15"
                + "\n3.\n🧙🏻‍♂️ \(game.text.magician)\n💉: 60. 💪: 75. 👨‍⚕️: 35"
            let input = Utilities.waitForInput(message: message, condition: 1...3)
            
            var character = Character()
            switch input {
            case 1:
                character = Knight()
            case 2:
                character = Archer()
            case 3:
                character = Magician()
            default:
                break
            }
            
            var characterName = ""
            var names = [String]()
            repeat {
                print("\(game.text.nameCharacter) \(team.count + 1). \(game.text.nameConstraints)")
                characterName = readLine()!.normalize()
            } while characterName.isBlank || Utilities.nameExists(names: names, name: characterName)
            
            print(characterName)
            character.name = characterName
            names.append(characterName)
            team.append(character)
        }
        
    }
    
    /// Allows user to attack or to heal a team member
    func move(against player: Player) {
        let message = "\n\n\(game.text.turn) \(name)"
            + "\n1.⚔️ \(game.text.attack)"
            + "\n2.💉 \(game.text.heal)\n"
        
        let action = Utilities.waitForInput(message: message, condition: 1...2)
        action == 1 ? attack(against: player) : heal()
        
    }
    /// Allows user to chose the team member that's going to attack and the enemy that will be attacked
    func attack(against player: Player) {
        
        let range = self.rangeTeam()
        let attackerIndex = Utilities.waitForInput(message: game.text.whoAttacks + range, condition: 1...team.count) - 1
        let attacker = team[attackerIndex]
        
        Weapon.randomWeapon(character: attacker)
        
        
        let rangeEnemy = player.rangeTeam()
        let enemyIndex = Utilities.waitForInput(message: game.text.whoIsAttacked + rangeEnemy, condition: 1...player.team.count) - 1
        let enemy = player.team[enemyIndex]
        
        attacker.attackEnemy(character: enemy)
                
        if enemy.isDead() {
            
            print("\(enemy.name) \(game.text.isDead) \n")
            let characterIndex = player.team.firstIndex(of: enemy)
            player.team.remove(at: characterIndex!)
            
        } else { print("\(enemy.name) \(game.text.healthIs) \(enemy.health)") }
    }
    
    /// Allows user to increase one of his members health
    func heal() {
        
        let range = self.rangeTeam()
        
        let healerIndex = Utilities.waitForInput(message: game.text.whoHeals + range, condition: 1...team.count) - 1
        let healer = team[healerIndex]
                
        let comradeIndex = Utilities.waitForInput(message: game.text.whoIsHealed + range, condition: 1...team.count) - 1
        let comrade = team[comradeIndex]
        
        healer.healComrade(character: comrade)
        print("\(comrade.name) \(game.text.healthIs) \(comrade.health)")
    }
    
    /// Returns a string with information (name, health, power...) about all the members of the team
    func rangeTeam() -> String {
        
        var range = ""
        for i in 0..<self.team.count {
            let teamInfo = "\n\(i+1). \(team[i].emoji) \(team[i].name). 💉: \(team[i].health). 💪: \(team[i].weapon.power). 👨‍⚕️ \(team[i].healingPower)"
            range.append(teamInfo)
        }
        return range
    }
    
}


// rpg/Model/Text.swift
//
//  Lang.swift
//  rpg
//
//  Created by Cristian Rojas on 16/07/2020.
//  MIT
//

/// Declares all the strings we're going to print to the user in the game
struct Text {
    
    var welcome = "\n\nWelcome to RPG madness"
    var chooseYourName = "what's your name?"
    var nameCharacter = "Name the character"
    var nameConstraints = "Name can't be empty nor taken"
    var chooseKind = "Choose the kind of the character"
    var character = "Character"
    var won = "won"
    var attack = "Attack"
    var heal = "Heal"
    var whoAttacks = "Who's going to attack?"
    var whoHeals = "Who's going to heal?"
    var whoIsAttacked = "Who's going to be attacked?"
    var whoIsHealed = "Who's going to be healed?"
    var healthIs = "health is now:"
    var isDead = "is dead!"
    var chooseNumberOfCharacters = "Choose the number of characters per player (at least 2)"
    var knight = "Knight"
    var magician = "Magician"
    var archer = "Archer"
    var foundWeapon = "has found a weapon. Power: "
    var turn = "Turn:"
    var enterNumber = "Enter number"
    var leftoutof = "left characters out of"
    var movements = "movements"
    
    /// Allows user to choose the game language. Declared as a mutating function because the strings are stored in a struct
    mutating func setLang() {
        
        let languages = "\n\n\n1. 🥖 Français"
        + "\n2. 💃🏻 Español"
        + "\n3. 🏈 English"
        
        let choice = Utilities.waitForInput(message: languages, condition: 1...3)
        
        /// Changes the languege of the game strings to the choosen one
        switch choice {
        case 1:
            welcome = "\n\nBienvenu à RPGmadness"
            chooseYourName = "quel est ton prenom?"
            nameCharacter = "Donne un nom au personnage"
            nameConstraints = "Le nom ne peut pas être vide ni repété"
            chooseKind = "Chossi la classe du personage"
            character = "Personnage"
            won = "gagne"
            attack = "Attaquer"
            heal = "Guérir"
            whoAttacks = "Qui va à attaquer?"
            whoHeals = "Qui va guérir?"
            whoIsAttacked = "Qui sera attaqué?"
            whoIsHealed = "Qui sera guéri?"
            healthIs = "vie:"
            isDead = "est mort!"
            chooseNumberOfCharacters = "Choissisez le nombre de personnages par joueur (2 au minimum)"
            knight = "Chevalier"
            magician = "Magicien"
            archer = "Archer"
            foundWeapon = "a trouvé une arme. Pouvoir de l'arme:"
            turn = "Tour:"
            enterNumber = "Rentrez un numéro"
            leftoutof = "personnages restent sur"
            movements = "mouvements"
            
        case 2:
            welcome = "\n\nBienvenido a RPGmadness"
            chooseYourName = "cuál es tu nombre?"
            nameCharacter = "Da un nombre al personaje"
            nameConstraints = "El nombre no puede estar vacío ni repetido"
            chooseKind = "Elije la clase del personaje"
            character = "Personaje"
            won = "gana"
            attack = "Atacar"
            heal = "Curar"
            whoAttacks = "Quién va a atacar?"
            whoHeals = "Quién cura?"
            whoIsAttacked = "Quién será atacado?"
            whoIsHealed = "Quién será curado?"
            healthIs = "vida:"
            isDead = "ha muerto!"
            chooseNumberOfCharacters = "Elije el número de personajes por jugador (2 como mínimo)"
            knight = "Caballero"
            magician = "Mago"
            archer = "Arquero"
            foundWeapon = "ha encontrado un arma. Poder del arma:"
            turn = "Turno:"
            enterNumber = "Escribe el número"
            leftoutof = "personajes de"
            movements = "movimientos"
            
        case 3:
            return
        default:
            break
        }
    }
    
}


// rpg/Model/Utilities.swift
//
//  Utilities.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.


import Foundation

/// Utility methods to be called within the project
class Utilities {
    
    /// Readline alike function that returns an Int? (Nil if user's input is a string)
    fileprivate static func readInt() -> Int? {
        let int : Int? = readLine().flatMap(Int.init(_:))
        return int
    }
    
    /// Ask till user enters an integer
    fileprivate static func waitForInt() -> Int {
        
        var number : Int?
        repeat {
            number = self.readInt()
        } while number == nil
        return number!
    }
    
    /// Asks user to enter an integer ranged between a choosen range.
    static func waitForInput(message: String, condition: ClosedRange<Int>) -> Int {
        var choice : Int
        repeat {
            print(message)
            choice = self.waitForInt()
        } while !condition.contains(choice)
        return choice
    }
    
    /// Checks if a string "name" exists in an array "names" and returns true if so
    static func nameExists(names: [String], name: String) -> Bool {
        var exists = false
        if names.firstIndex(of: name) != nil {
            exists = true
        }
        return exists
    }
}

extension String {
    
    ///Apply a lowercase & capitalize filter to a string
    func normalize() -> String {
        var newString = self.lowercased()
        newString = self.capitalized
        return newString
    }
    /// Checks if a string is blank
    var isBlank: Bool {
        return allSatisfy({ $0.isWhitespace })
    }
}


// rpg/Model/Weapon.swift
//
//  Weapon.swift
//  rpg
//
//  Created by Cristian Rojas on 15/07/2020.
//  MIT
//

import Foundation

class Weapon {
    /// Defines the power of the weapon
    var power : Int = 40
    
    /// Creates a weapon with a random power
    static func randomWeapon(character: Character) {
        let random = Int.random(in: 1...3)
        let matchingNumber = 1
        if random == matchingNumber {
            let factor = Double.random(in: 0.5...3.0)
            let power = Double(character.weapon.power) * factor
            character.weapon.power = Int(power)
            print("\(character.name) \(game.text.foundWeapon) \(character.weapon.power)")
        }
    }
}


// rpg/Model/Weapons/Arc.swift
//
//  Arc.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Arc : Weapon {
    override init() {
           super.init()
           power = 60
       }
}


// rpg/Model/Weapons/Sword.swift
//
//  Sword.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Sword : Weapon {
    override init() {
        super.init()
        power = 50
    }
}


// rpg/Model/Weapons/Wand.swift
//
//  Wand.swift
//  rpg
//
//  Created by Cristian Rojas on 30/07/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import Foundation

class Wand : Weapon {
     override init() {
           super.init()
           power = 70
       }
}



// p3-instagrid.swift

// p4_Instagrid/AppDelegate.swift
//
//  AppDelegate.swift
//  p4_Instagrid
//
//  Created by Cristian Rojas on 18/08/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle
    @available(iOS 13, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    @available(iOS 13, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}



// p4_Instagrid/Controller/ViewController.swift
//
//  ViewController.swift
//  p4_Instagrid
//
//  Created by Cristian Rojas on 18/08/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet var layoutCollection: [UIButton]!
    @IBOutlet var gridButtonCollection: [GridButton]!
    @IBOutlet weak var gridView: UIView!
    @IBOutlet weak var swipeLabel: UILabel!
    
    private let selectedCheckboxImage = UIImage(named: "Selected")
    private var imagePicker = UIImagePickerController()
    
    /// Retrieves the pressed button. Useful for changing it's image with the image picker delegate methods
    private var pressedGridButton: GridButton!
    
    /// Retrieves one of the three selected layotus
    private var selectedLayout: Int = 2
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setSwipeGestures()
        setSwipeLabelOnLaunch()
        
    }
    
    /// Changes swipelabel text on rotation
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        swipeLabel.text = fromInterfaceOrientation.isLandscape ? "Swipe up to share" : "Swipe left to share"
    }
    
    /// Allows user to pick an image for the grid by using the imagePicker
    @IBAction func gridButtonPressed(_ sender: UIButton) {
        if let sender = sender as? GridButton {
            pressedGridButton = sender
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            imagePicker.allowsEditing = true
            imagePicker.delegate = self
            self.present(imagePicker, animated: true)
        }
    }
    
    /// Allows user to chose the layout
    @IBAction func layoutButtonPressed(_ sender: UIButton) {
        switch sender.tag {
        case 1:
            selectedLayout = 1
            hideButton(with: 1, sender: sender)
        case 2:
            selectedLayout = 2
            hideButton(with: 3, sender: sender)
        case 3:
            selectedLayout = 3
            clearLayoutButtons()
            clearGridButtons()
            sender.setImage(selectedCheckboxImage, for: .normal)
        default:
            break
        }
    }
}

// MARK: Private methods
private extension ViewController {
    
    func setSwipeGestures() {
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(shareOnSwipe(_:)))
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(shareOnSwipe(_:)))
        
        swipeUp.direction = .up
        swipeLeft.direction = .left
        
        view.addGestureRecognizer(swipeUp)
        view.addGestureRecognizer(swipeLeft)
    }
    
    /// Creates an activity controller on swipe left or up
    @objc func shareOnSwipe(_ sender: UISwipeGestureRecognizer) {
        switch selectedLayout {
        case 1, 2:
            itemsWithPicture() == 3 ? sharerActivityController(sender: sender) : emptyItemsAlert(sender: sender)
        case 3:
            itemsWithPicture() == 4 ? sharerActivityController(sender: sender) : emptyItemsAlert(sender: sender)
        default:
            break
        }
    }
    
    /// Changes swipe label text if the app is launched in landscape mode
    private func setSwipeLabelOnLaunch() {
        let orientation = UIApplication.shared.statusBarOrientation
        if orientation.isLandscape {
            swipeLabel.text = "Swipe left to share"
        }
    }
    
    /// Returns the number of items of the grid that have a picture (UIButton.backgroundImage != nil)
    func itemsWithPicture() -> Int {
        var buttonsWithBackground = [GridButton]()
        gridButtonCollection.forEach {
            if $0.backgroundImage(for: .normal) != nil {
                buttonsWithBackground.append($0)
            }
            
        }
        return buttonsWithBackground.count
    }
    
    /// Presents an activity controller that allows the user to share a picture of the grid collage
    func sharerActivityController(sender: UISwipeGestureRecognizer) {
        guard let image = gridView.asImage()
        else { return }
        
        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        presentView(sender: sender, view: activityController)
    }
    
    /// Presents an alert controller if there are empty items of the grid (no picture provided by the user)
    func emptyItemsAlert(sender: UISwipeGestureRecognizer) {
        let alert = UIAlertController(title: "Empty items", message: "Some of the the grid items haven't a picture yet. Please provide a picture for all the items", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        presentView(sender: sender, view: alert)
    }
    
    private func presentView(sender: UISwipeGestureRecognizer, view: UIViewController) {
        let orientation = UIApplication.shared.statusBarOrientation
        if sender.direction == .up && orientation.isPortrait {
            self.present(view, animated: true)
        } else if sender.direction == .left && orientation.isLandscape {
            self.present(view, animated: true)
        }
    }
    
    /// Clear checkbox image every time user changes layout
    func clearLayoutButtons() {
        layoutCollection.forEach {
            $0.setImage(nil, for: .normal)
        }
    }
    
    /// Clears grid button image every time user changes layout
    func clearGridButtons() {
        gridButtonCollection.forEach {
            $0.setImage(UIImage(named: "Combined Shape"), for: .normal)
            $0.setBackgroundImage(nil, for: .normal)
            $0.isHidden = false
        }
    }
    
    /// Hides a buttton on the grid in order to adapt to the selected layout
    func hideButton(with tag: Int, sender: UIButton) {
        clearLayoutButtons()
        clearGridButtons()
        
        sender.setImage(selectedCheckboxImage, for: .normal)
        
        gridButtonCollection.forEach {
            if $0.tag == tag {
                $0.isHidden = true
            }
        }
    }
}

// MARK: UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else { return }
        
        pressedGridButton.setPicture(backgroundImage: image)
        pressedGridButton.layoutIfNeeded()
        pressedGridButton.subviews.first?.contentMode = .scaleAspectFill
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}




// p4_Instagrid/Extension/UIView.swift
//
//  UIView.swift
//  p4_Instagrid
//
//  Created by Cristian Rojas on 12/09/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import UIKit

extension UIView {
    
    func asImage() -> UIImage? {
        
        UIGraphicsBeginImageContext(self.frame.size)
        guard let currentContext = UIGraphicsGetCurrentContext() else { return nil }
        self.layer.render(in: currentContext)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        guard let cgImage = image.cgImage else { return nil }
        return UIImage(cgImage: cgImage)
    }
}



// p4_Instagrid/SceneDelegate.swift
//
//  SceneDelegate.swift
//  p4_Instagrid
//
//  Created by Cristian Rojas on 18/08/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import UIKit

@available(iOS 13, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}



// p4_Instagrid/View/GridButton.swift
//
//  GridButton.swift
//  p4_Instagrid
//
//  Created by Cristian Rojas on 12/09/2020.
//  Copyright © 2020 Cristian Rojas. All rights reserved.
//

import UIKit

class GridButton: UIButton {
    
    func setPicture(backgroundImage: UIImage?) {
        // Sets Aspect of the backgroundImage
        self.setImage(nil, for: .normal)
        self.setBackgroundImage(backgroundImage, for: .normal)
    }
}



// p4-reciplease.swift

// Reciplease/Application/AppDelegate.swift
//
//  AppDelegate.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 20/03/2021.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Necessary on iOS11
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        setupTabbar()
        
        let attrs = [
            NSAttributedString.Key.foregroundColor: UIColor.darkPurple,
            NSAttributedString.Key.font: UIFont.textBiggest
        ]

            UINavigationBar.appearance().titleTextAttributes = attrs
        
        
        
        return true
    }

    // MARK: UISceneSession Lifecycle
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

// MARK: - App UI
private extension AppDelegate {
    func setupTabbar() {
        let appearance = UITabBar.appearance()
        
        
        appearance.backgroundColor = .cream
    
        appearance.shadowImage =  UIImage()
        appearance.backgroundImage = UIImage()
        
        let tintColor = UIColor.darkPurple
        
        appearance.unselectedItemTintColor = tintColor.withAlphaComponent(0.4)
        
        let attributes = [
            NSAttributedString.Key.foregroundColor: tintColor,
        ]
        
        UITabBar.appearance().tintColor = tintColor
        UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .normal)
    }
}


// Reciplease/Application/SceneDelegate.swift
//
//  SceneDelegate.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 20/03/2021.
//

import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
//        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}



// Reciplease/Data/Api.swift
//
//  Api.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import Foundation

enum Api {
    static let edamam: RecipleaseApiInput = RecipleaseApi()
}


// Reciplease/Data/Cache/CacheManager.swift
//
//  CacheManager.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 23/04/2021.
//

import Foundation

struct CacheManager {
    var recipeImages: [String: Data] = [:]
    
    mutating func clearCache() {
        recipeImages = [:]
    }
}

var cacheManager = CacheManager()


// Reciplease/Data/Client/Edamam.swift
//
//  Edamam.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 20/03/2021.
//

import Alamofire

enum Edamam {
    static let baseURL = "https://api.edamam.com/"
    static let apiKey = ""
    static let appId = ""
    
    case getSearch(query: String)
}

extension Edamam: URLRequestConvertible {
    
    var path: String {
        switch self {
        case .getSearch(_):
            return "search"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getSearch(_):
            return .get
        }
    }

    
    var urlComponents: [URLQueryItem] {
        var components = [URLQueryItem]()
        components.append(URLQueryItem(name: "app_id", value: Edamam.appId))
        components.append(URLQueryItem(name: "app_key", value: Edamam.apiKey))
        
        switch self {
        case .getSearch(let query):
            components.append(URLQueryItem(name: "q", value: query))
            
        }
        return components
    }
    
    func asURLRequest() throws -> URLRequest {
        var urlRequest: URLRequest
        
        switch self {
        case .getSearch(_):
            var components = URLComponents(string: Edamam.baseURL+"/"+path)
            
            components?.queryItems = urlComponents
            components?.queryItems = urlComponents
            
            urlRequest = URLRequest(url: (components?.url!)!)
        }
        
        return urlRequest
    }
    
}


// Reciplease/Data/Client/EdamamApi.swift
//
//  EdamamApi.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 20/03/2021.
//

import Alamofire

protocol RecipleaseApiInput {
    func getSearch(query: String, completion: @escaping (Result<RecipeResponse, Error>) -> Void)
}

class RecipleaseApi: RecipleaseApiInput {
    func getSearch(query: String, completion: @escaping (Result<RecipeResponse, Error>) -> Void) {
        
        do {
            let request = try Edamam.getSearch(query: query).asURLRequest()
            
            AF.request(request).responseJSON { (response) in
                switch response.result {
                case .failure(_):
                    completion(.failure(Error(type: .networkError)))
                case .success:
                    guard let data = response.data else {
                        completion(.failure(Error(type: .noDataError)))
                        return
                    }
                    
                    do {
                        let recipes = try JSONDecoder().decode(RecipeResponse.self, from: data)
                        completion(.success(recipes))
                        return
                    } catch {
                        completion(.failure(Error(type: .decodingError)))
                    }
                }
            }
        } catch {
            return
        }
    }
}


// Reciplease/Data/CoreData/CoreDataStack.swift
//
//  CoreDataStack.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import CoreData

//class CoredataStack {
//    lazy var persistentContainer: NSPersistentContainer = {
//        /*
//         The persistent container for the application. This implementation
//         creates and returns a container, having loaded the store for the
//         application to it. This property is optional since there are legitimate
//         error conditions that could cause the creation of the store to fail.
//        */
//        let container = NSPersistentContainer(name: "Reciplease")
//        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
//            if let error = error as NSError? {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//
//                /*
//                 Typical reasons for an error here include:
//                 * The parent directory does not exist, cannot be created, or disallows writing.
//                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
//                 * The device is out of space.
//                 * The store could not be migrated to the current model version.
//                 Check the error message to determine what the actual problem was.
//                 */
//                fatalError("Unresolved error \(error), \(error.userInfo)")
//            }
//        })
//        return container
//    }()
//
//    // MARK: - Core Data Saving support
//
//    func saveContext () {
//        let context = persistentContainer.viewContext
//        if context.hasChanges {
//            do {
//                try context.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nserror = error as NSError
//                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
//            }
//        }
//    }
//}

open class CoreDataStack {
  public static let modelName = "Reciplease"

  public static let model: NSManagedObjectModel = {
    // swiftlint:disable force_unwrapping
    let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")!
    return NSManagedObjectModel(contentsOf: modelURL)!
  }()
  // swiftlint:enable force_unwrapping
    
  public init() {
  }

  public lazy var mainContext: NSManagedObjectContext = {
    return self.storeContainer.viewContext
  }()

  public lazy var storeContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: CoreDataStack.modelName, managedObjectModel: CoreDataStack.model)
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  public func newDerivedContext() -> NSManagedObjectContext {
    let context = storeContainer.newBackgroundContext()
    return context
  }

  public func saveContext() {
    saveContext(mainContext)
  }

  public func saveContext(_ context: NSManagedObjectContext) {
    if context != mainContext {
      saveDerivedContext(context)
      return
    }

    context.perform {
      do {
        try context.save()
      } catch let error as NSError {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
  }

  public func saveDerivedContext(_ context: NSManagedObjectContext) {
    context.perform {
      do {
        try context.save()
      } catch let error as NSError {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }

      self.saveContext(self.mainContext)
    }
  }
}



// Reciplease/Data/CoreData/RecipesCoredataManager.swift
//
//  RecipeCoredataManager.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import CoreData
import Foundation

class RecipesCoredataManager {
    
    let stack: CoreDataStack
    let managedObjectContext: NSManagedObjectContext
    
    
    init(stack: CoreDataStack, managedObject: NSManagedObjectContext) {
        self.stack = stack
        self.managedObjectContext = managedObject
    }
    
    func storedRecipes() -> [RecipeCD]? {
        let reportFetch: NSFetchRequest<RecipeCD> = RecipeCD.fetchRequest()
            do {
              let results = try managedObjectContext.fetch(reportFetch)
              return results
            } catch let error as NSError {
              print("Fetch error: \(error) description: \(error.userInfo)")
            }
            return nil
    }

    func add(recipe: RecipeBO) {
        
        let newRecipe = RecipeCD(context: managedObjectContext)
        
        newRecipe.uri = recipe.uri
        newRecipe.label = recipe.label
        newRecipe.image = recipe.image
        newRecipe.source = recipe.source
        newRecipe.url = recipe.url
        newRecipe.shareAs = recipe.shareAs
        newRecipe.yield = Int16(recipe.yield ?? 0)
        newRecipe.ingredients = recipe.ingredients
        newRecipe.totalTime = Int32(recipe.totalTime)
        
        stack.saveContext(managedObjectContext)
    }
    
    
    func delete(recipe: RecipeCD) {
        managedObjectContext.delete(recipe)
        stack.saveContext(managedObjectContext)
    
    }
}


// Reciplease/Data/Repository/RecipesRepository.swift
//
//  RecipesRepository.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import Foundation

enum SearchViewState: Equatable {
    case loading
    case success(RecipeResponse)
    case error
    
    var isLoading: Bool {
        self == .loading
    }
}

protocol RecipesRepositoryInput {
    var output: RecipesRepositoryOutput? { get set }
    func performSearch(query: String)
}

protocol RecipesRepositoryOutput: AnyObject {
    func didPerformSearch(_ result: Result<RecipeResponse, Error>)
    func didUpdate(state: SearchViewState)
}

class RecipesRepository: RecipesRepositoryInput {
    
    weak var output: RecipesRepositoryOutput?
    private var api: RecipleaseApiInput
    
    init(api: RecipleaseApiInput = Api.edamam) {
        self.api = api
    }

    func performSearch(query: String) {
        output?.didUpdate(state: .loading)
        api.getSearch(query: query) { [weak output] result in
            output?.didPerformSearch(result)
        }
    }
}


// Reciplease/Domain/Model/Api/Recipe.swift
//
//  Recipe.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Foundation

struct Recipe: Equatable {
    let uri: String
    let label: String
    let image: String
    let source: String
    let url: String
    let shareAs: String
    let yield: Int
    let ingredients: [String]
    let totalTime: Int
}

extension Recipe: Decodable {
    private enum CodingKeys: String, CodingKey {
        case uri
        case label
        case image
        case source
        case url
        case shareAs
        case yield
        case ingredients
        case totalTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uri = try container.decode(String.self, forKey: .uri)
        url = try container.decode(String.self, forKey: .url)
        label = try container.decode(String.self , forKey: .label)
        image = try container.decode(String.self, forKey: .image)
        source = try container.decode(String.self, forKey: .source)
        shareAs = try container.decode(String.self, forKey: .shareAs)
        yield = try container.decode(Int.self, forKey: .yield)
        totalTime = try container.decode(Int.self, forKey: .totalTime)
        
        let tmpIngredients = try container.decode([Ingredient].self, forKey: .ingredients)
        ingredients = tmpIngredients.map { $0.text }
        
    }
}


// Reciplease/Domain/Model/Api/RecipesResponse.swift
//
//  RecipesResponse.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import CoreData
import Foundation

struct RecipeResponse: Equatable {
    let recipes: [Recipe]
}

extension RecipeResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hits
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hits = try container.decode([Hit].self, forKey: .hits)
        recipes = hits.map { $0.recipe }
    }
}


// Reciplease/Domain/Model/Error.swift
//
//  Error.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import Foundation

enum ErrorType: Equatable {
    case invalidURL
    case noDataError
    case decodingError
    case networkError
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid url"
        case .noDataError:
            return "No data found"
        case .decodingError:
            return "Fail while decoding"
        case .networkError:
            return "Network error"
        }
    }
}

struct Error: Swift.Error {
    let type: ErrorType
}


// Reciplease/Domain/Model/FoodEmoji.swift
//
//  FoodEmoji.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

enum FoodEmojis: String, CaseIterable {
    case Chicken = "🍗"
    case Tomato = "🍅"
    case Grappes = "🍇"
    case Melon = "🍈"
    case Watermelon = "🍉"
    case Tangerine = "🍊"
    case Lemon = "🍋"
    case Banana = "🍌"
    case Pineapple = "🍍"
    case Mango = "🥭"
    case Apple = "🍎"
    case Pear = "🍐"
    case Peach = "🍑"
    case Cherries = "🍒"
    case Strawberry = "🍓"
    case Kiwi = "🥝"
    case Coconut = "🥥"
    case Avocado = "🥑"
    case Eggplant = "🍆"
    case Potato = "🥔"
    case Carrot = "🥕"
    case Corn = "🌽"
    case HotPepper = "🌶️"
    case Cucumber = "🥒"
    case LeafyGreen = "🥬"
    case Broccoli = "🥦"
    case Garlic = "🧄" //
    case Onion = "🧅" //
    case Mushroom = "🍄"
    case Peanuts = "🥜"
    case Chestnut = "🌰"
    case Bread = "🍞"
    case Cheese = "🧀"
    case Beef = "🥩"
    case Bacon = "🥓"
    case Taco = "🌮"
    case Burrito = "🌯"
    case Egg = "🥚"
    case Salad = "🥗"
    case Butter = "🧈" //
    case Salt = "🧂"
    case Rice = "🍚"
    case Pasta = "🍝"
    case Shrimp = "🦐"
    case Oyster = "🦪" //
    case IceCream = "🍦"
    case Chocolate = "🍫"
    case Honey = "🍯"
    case Milk = "🥛"
    case Coffee = "☕"
    case Tea = "🍵"
    case Sake = "🍶"
    case Wine = "🍷"
    case Beer = "🍺"
    
    static var model: [String: String] {
        Dictionary(uniqueKeysWithValues: FoodEmojis.allCases.map{ ($0.name.lowercased(), $0.rawValue) })
    }
    
    var name: String {
        switch self {
        case .Chicken: return S.Chicken
        case .Tomato: return S.Tomato
        case .Grappes: return S.Grappes
        case .Melon: return S.Melon
        case .Watermelon: return S.Watermelon
        case .Tangerine: return S.Tangerine
        case .Lemon: return S.Lemon
        case .Banana: return S.Banana
        case .Pineapple: return S.Pineapple
        case .Mango: return S.Mango
        case .Apple: return S.Apple
        case .Pear: return S.Pear
        case .Peach: return S.Peach
        case .Cherries: return S.Cherries
        case .Strawberry: return S.Strawberry
        case .Kiwi: return S.Kiwi
        case .Coconut: return S.Coconut
        case .Avocado: return S.Avocado
        case .Eggplant: return S.Eggplant
        case .Potato: return S.Potato
        case .Carrot: return S.Carrot
        case .Corn: return S.Corn
        case .HotPepper: return S.HotPepper
        case .Cucumber: return S.Cucumber
        case .LeafyGreen: return S.LeafyGreen
        case .Broccoli: return S.Broccoli
        case .Garlic: return S.Garlic
        case .Onion: return S.Onion
        case .Mushroom: return S.Mushroom
        case .Peanuts: return S.Peanuts
        case .Chestnut: return S.Chestnut
        case .Bread: return S.Bread
        case .Cheese: return S.Cheese
        case .Beef: return S.Beef
        case .Bacon: return S.Bacon
        case .Taco: return S.Taco
        case .Burrito: return S.Burrito
        case .Egg: return S.Egg
        case .Salad: return S.Salad
        case .Butter: return S.Butter
        case .Salt: return S.Salt
        case .Rice: return S.Rice
        case .Pasta: return S.Pasta
        case .Shrimp: return S.Shrimp
        case .Oyster: return S.Oyster
        case .IceCream: return S.IceCream
        case .Chocolate: return S.Chocolate
        case .Honey: return S.Honey
        case .Milk: return S.Milk
        case .Coffee: return S.Coffee
        case .Tea: return S.Tea
        case .Sake: return S.Sake
        case .Wine: return S.Wine
        case .Beer: return S.Beer
        }
    }
}


// Reciplease/Domain/Model/Hit.swift
//
//  Hit.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Foundation

struct Hit: Decodable {
    let recipe: Recipe
}


// Reciplease/Domain/Model/Ingredient.swift
//
//  Ingredient.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Foundation


// MARK: - Ingredient
struct Ingredient: Equatable, Codable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case text
    }
}


// Reciplease/Domain/Model/ListType.swift
//
//  ListType.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Foundation

enum ListType {
    case search
    case favorite
}


// Reciplease/Domain/Model/RecipeBO.swift
//
//  RecipeBO.swift
//  Reciplease
//
//  Created by Cristian Rojas on 01/05/2021.
//

import Foundation

struct RecipeBO {
    
    let uri: String
    let label: String
    let image: String
    let source: String
    let url: String
    let shareAs: String
    let yield: Int
    let ingredients: [String]
    let totalTime: Int
    
    let isFavorite: Bool
    
    init(recipe: Recipe, isFavorite: Bool) {
        uri = recipe.uri
        label = recipe.label
        image = recipe.image
        source = recipe.source
        url = recipe.url
        shareAs = recipe.shareAs
        yield = recipe.yield
        ingredients = recipe.ingredients
        totalTime = recipe.totalTime
        
        self.isFavorite = isFavorite
    }
    
    init(recipe: RecipeCD) {
        uri = recipe.uri ?? "Empty string"
        label = recipe.label ?? "Empty string"
        image = recipe.image ?? "Empty string"
        source = recipe.source ?? "Empty string"
        url = recipe.url ?? ""
        shareAs = recipe.shareAs ?? "Empty string"
        yield = Int(recipe.yield)
        ingredients = recipe.ingredients ?? [ ]
        totalTime = Int(recipe.totalTime)
        
        
        isFavorite = true
    }
}


// Reciplease/Extension/Array+filterDuplicates.swift
//
//  Array+filterDuplicates.swift
//  Reciplease
//
//  Created by Cristian Rojas on 29/05/2021.
//

import Foundation

extension Array where Element: Equatable {
    func filterDuplicates() -> [Element] {
        var newArray = [Element]()
        for item in self {
            if newArray.firstIndex(of: item) == nil {
                newArray.append(item)
            }
        }
        return newArray
    }
}


// Reciplease/Extension/Array+getOrNull.swift
//
//  Array+getOrNull.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import Foundation

extension Array {
    
    func getOrNull(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


// Reciplease/Extension/String+appText.swift
//
//  String+appText.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import Foundation

enum S {
    
    // MARK: - Generics
    static let search = "search".localized
    static let attention = "attention".localized
    static let ok = "ok".localized
    static let done = "done".localized
    
    // MARK: - Search
    static let searchHeading = "search_heading".localized
    static let searchSubHeading = "search_subheading".localized
    static let searchPlaceholder = "search_placeholder".localized
    static let searchIngredientList = "search_ingredient_list".localized
    static let searchClearAll = "search_clear_all".localized
    
    static let getDirections = "get_directions".localized
    
    // MARK: - Errors
    static let errorUnknown = "errorUnknown".localized
    static let errorEmptyIngredients = "errorEmptyIngredients".localized
    static let errorIngredientExists = "errorIngredientExists".localized
    static let errorAddingToFavoritres = "error_adding_to_favorites".localized
    static let errorNetwork = "errorNetwork".localized
    
    
    static let favorites = "favorites".localized
    static let noFavoritesYet = "no_favorites_yet".localized
    static let results = "results".localized
    static let noResultsFound = "no_results_found".localized
    static let howToFavorites = "how_to_favorites".localized
    
    
    
    // MARK: - Ingredients
    static let Chicken = "Chicken".localized
    static let Tomato = "Tomato".localized
    static let Grappes = "Grappes".localized
    static let Melon = "Melon".localized
    static let Watermelon = "Watermelon".localized
    static let Tangerine = "Tangerine".localized
    static let Lemon = "Lemon".localized
    static let Banana = "Banana".localized
    static let Pineapple = "Pineapple".localized
    static let Mango = "Mango".localized
    static let Apple = "Apple".localized
    static let Pear = "Pear".localized
    static let Peach = "Peach".localized
    static let Cherries = "Cherries".localized
    static let Strawberry = "Strawberry".localized
    static let Kiwi = "Kiwi".localized
    static let Coconut = "Coconut".localized
    static let Avocado = "Avocado".localized
    static let Eggplant = "Eggplant".localized
    static let Potato = "Potato".localized
    static let Carrot = "Carrot".localized
    static let Corn = "Corn".localized
    static let HotPepper = "HotPepper".localized
    static let Cucumber = "Cucumber".localized
    static let LeafyGreen = "LeafyGreen".localized
    static let Broccoli = "Broccoli".localized
    static let Garlic = "Garlic".localized
    static let Onion = "Onion".localized
    static let Mushroom = "Mushroom".localized
    static let Peanuts = "Peanuts".localized
    static let Chestnut = "Chestnut".localized
    static let Bread = "Bread".localized
    static let Cheese = "Cheese".localized
    static let Beef = "Beef".localized
    static let Bacon = "Bacon".localized
    static let Taco = "Taco".localized
    static let Burrito = "Burrito".localized
    static let Egg = "Egg".localized
    static let Salad = "Salad".localized
    static let Butter = "Butter".localized
    static let Salt = "Salt".localized
    static let Rice = "Rice".localized
    static let Pasta = "Pasta".localized
    static let Shrimp = "Shrimp".localized
    static let Oyster = "Oyster".localized
    static let IceCream = "IceCream".localized
    static let Chocolate = "Chocolate".localized
    static let Honey = "Honey".localized
    static let Milk = "Milk".localized
    static let Coffee = "Coffee".localized
    static let Tea = "Tea".localized
    static let Sake = "Sake".localized
    static let Wine = "Wine".localized
    static let Beer = "Beer".localized
}


// Reciplease/Extension/String+Localized.swift
//
//  Strings+Localized.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}


// Reciplease/Extension/UIColor+Colors.swift
//
//  UIColor+Colors.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import UIKit

extension UIColor {
    static let salmon = UIColor(named:"salmon")!
    static let cream = UIColor(named: "cream")!
    static let darkPurple = UIColor(named: "darkPurple")!
    static let darkPurple50 = UIColor(named: "darkPurple50")!
    static let darkerCream = UIColor(named: "darkerCream")!
    static let paleBrown = UIColor(named: "paleBrown")!
    static let blood = UIColor(named: "blood")!
    static let pink = UIColor(named: "pink")!
    static let brightSalmon = UIColor(named:"brightSalmon")!
    static let strongSalmon = UIColor(named: "strongSalmon")!
    static let deepGreen = UIColor(named: "deepGreen")!
    
    static let paleBrown50 = UIColor(named: "paleBrown50")!
    static let cream50 = UIColor(named: "cream50")!
}


// Reciplease/Extension/UIEdgeInsets+same.swift
//
//  UIEdgeInsets+same.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit

extension UIEdgeInsets {
    static func same(with float: CGFloat) -> UIEdgeInsets {
        return UIEdgeInsets(top: float, left: float, bottom: float, right: float)
    }
}


// Reciplease/Extension/UIFont+Fonts.swift
//
//  UIFont+Fonts.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 28/03/2021.
//

import UIKit

extension UIFont {
    class var textBiggest: UIFont {
        return UIFont(name: "FuturaPT-Bold", size: 24.0)!
    }
    
    class var textBig: UIFont {
        return UIFont(name: "FuturaPT-Bold", size: 18.0)!
    }
    
    class var textMedium: UIFont {
        return UIFont(name: "FuturaPT-Medium", size: 16.0)!
    }
    
    class var textSmall: UIFont {
        return UIFont(name: "FuturaPT-Medium", size: 12.0)!
    }
}


// Reciplease/Extension/UITextField+addDoneToolbar.swift
//
//  UITextField+addDoneToolbar.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import Foundation
import UIKit

extension UITextField {
    func addDoneToolbar(onDone: (target: Any, action: Selector)? = nil) {
        let onDone = onDone ?? (target: self, action: #selector(doneButtonTapped))
        
        let toolbar: UIToolbar = UIToolbar()
        toolbar.barStyle = .default
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(title: S.done, style: .done, target: onDone.target, action: onDone.action)
        ]
        
        toolbar.sizeToFit()
        
        self.inputAccessoryView = toolbar
    }
    
    @objc func doneButtonTapped() { self.resignFirstResponder() }
}



// Reciplease/Extension/UIViewController+escapeKeyboard.swift
//
//  UIViewController+escapeKeyboard.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 28/03/2021.
//

import UIKit

extension UIViewController {
    func escapeKeyboard() {
        let closeKeyboard = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        
        self.view.addGestureRecognizer(closeKeyboard)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}


// Reciplease/Extension/UIViewController+showAlert.swift
//
//  UIViewController+showAlert.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 04/04/2021.
//

import UIKit

extension UIViewController {
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: S.attention, message: message, preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(title: S.ok, style: .default)
        
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}


// Reciplease/Routing/NSObject+NameOfClass.swift
//
//  NSObject+NameOfClass.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Foundation


extension NSObject {
    class var nameOfClass: String {
        NSStringFromClass(self).components(separatedBy: ".").last!
    }
}


// Reciplease/Routing/Presentable.swift
//
//  Presentable.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit


protocol Presentable {
    func toPresent() -> UIViewController?
}

extension UIViewController: Presentable {
    
    func toPresent() -> UIViewController? {
        self
    }
}


// Reciplease/Routing/Routable.swift
//
//  Routable.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit

protocol Routable {
    /// Router build with a navigationController if available
    var router: RouterProtocol? { get }
}

extension UIViewController: Routable {
    var router: RouterProtocol? {
        guard let nc = navigationController else { return nil }
        return Router(rootController: nc)
    }
}


// Reciplease/Routing/RouterProtocol.swift
//
//  RouterProtocol.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit

// MARK: Router protocols
protocol RouterProtocol {
    
    func present(_ module: Presentable?)
    func present(_ module: Presentable?, animated: Bool)
    func present(_ module: Presentable?, withNavigationController: Bool, isFullScreen: Bool)
    
    func push(_ module: Presentable?)
    func push(_ module: Presentable?, hideBottomBar: Bool)
    func push(_ module: Presentable?, animated: Bool)
    func push(_ module: Presentable?, animated: Bool, completion: (() -> Void)?)
    func push(_ module: Presentable?, animated: Bool, hideBottomBar: Bool, completion: (() -> Void)?)
    
    func popModule()
    func popModule(animated: Bool)
    
    func dismissModule()
    func dismissModule(animated: Bool, completion: (() -> Void)?)
    
    func popToRootModule(animated: Bool)
}


class Router: RouterProtocol {
    
    private weak var rootController: UINavigationController?
    
    init(rootController: UINavigationController) {
        self.rootController = rootController
    }
    
    func present(_ module: Presentable?) {
        present(module, animated: true)
    }
    
    func present(_ module: Presentable?, animated: Bool) {
        guard let controller = module?.toPresent() else { return }
        rootController?.present(controller, animated: animated, completion: nil)
    }
    
    func presdent(_ module: Presentable?, animated: Bool, withNavigationController: Bool) {
        guard let controller = module?.toPresent() else { return }
        if withNavigationController {
            let navVC = UINavigationController(rootViewController: controller)
            navVC.modalPresentationStyle = .none
            rootController?.present(navVC, animated: animated, completion: nil)
        } else {
            rootController?.present(controller, animated: animated, completion: nil)
        }
    }
    
    func present(_ module: Presentable?, withNavigationController: Bool, isFullScreen: Bool) {
        guard let controller = module?.toPresent() else { return }
        var vc = controller
        if withNavigationController {
            vc = UINavigationController(rootViewController: controller)
        }
        
        if isFullScreen {
            vc.modalPresentationStyle = .fullScreen
        }
        rootController?.present(vc, animated: true, completion: nil)
    }
    
    func push(_ module: Presentable?) {
        push(module, animated: true)
    }
    
    func push(_ module: Presentable?, hideBottomBar: Bool) {
        push(module, animated: true, hideBottomBar: hideBottomBar, completion: nil)
    }
    
    func push(_ module: Presentable?, animated: Bool) {
        push(module, animated: animated, completion: nil)
    }
    
    func push(_ module: Presentable?, animated: Bool, completion: (() -> Void)?) {
        push(module, animated: animated, hideBottomBar: false, completion: completion)
    }
    
    func push(_ module: Presentable?, animated: Bool, hideBottomBar: Bool, completion: (() -> Void)?) {
        guard
            let controller = module?.toPresent(),
            (controller is UINavigationController == false)
            else { assertionFailure("Deprecated push UINavigationController."); return }
        
        controller.hidesBottomBarWhenPushed = hideBottomBar
        rootController?.pushViewController(controller, animated: animated)
    }
    
    func popModule() {
        popModule(animated: true)
    }
    
    func popModule(animated: Bool) {
        rootController?.popViewController(animated: animated)
    }
    
    func dismissModule() {
        dismissModule(animated: true, completion: nil)
    }
    
    func dismissModule(animated: Bool, completion: (() -> Void)?) {
        rootController?.dismiss(animated: animated, completion: completion)
    }
    
    func popToRootModule(animated: Bool) {
        rootController?.popToRootViewController(animated: animated)
    }
    
    func toPresent() -> UIViewController? {
        rootController
    }
    
}


// Reciplease/Routing/RoutingNavigationOption.swift
//
//  RoutingNavigationOption.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Foundation

struct RoutingNavigationOption {
    let type: RoutingType
    let withNavigationController: Bool
    let isFullScreen: Bool

    init(type: RoutingType = .push,
         withNavigationController: Bool = false,
         isFullScreen: Bool = false) {
        self.type = type
        self.withNavigationController = withNavigationController
        self.isFullScreen = isFullScreen
    }
}


// Reciplease/Routing/RoutingType.swift
//
//  RoutingType.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Foundation

enum RoutingType {
    case push
    case present
}



// Reciplease/Routing/Storyboards.swift
//
//  Storyboards.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Foundation

enum Storyboards: String {
    case list = "List"
    case search = "Search"
    case detail = "Detail"
}


// Reciplease/Routing/UIViewController+Storyboards.swift
//
//  UIViewController+Storyboards.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit

extension UIViewController {
    private class func instantiateControllerInStoryboard<T: UIViewController>(_ storyboard: UIStoryboard, identifier: String) -> T {
        return storyboard.instantiateViewController(withIdentifier: identifier) as! T
    }

    class func controllerInStoryboard(_ storyboard: UIStoryboard, identifier: String) -> Self {
        return instantiateControllerInStoryboard(storyboard, identifier: identifier)
    }

    class func controllerInStoryboard(_ storyboard: UIStoryboard) -> Self {
        return controllerInStoryboard(storyboard, identifier: nameOfClass)
    }

    class func controllerFromStoryboard(_ storyboard: Storyboards) -> Self {
        return controllerInStoryboard(UIStoryboard(name: storyboard.rawValue, bundle: nil), identifier: nameOfClass)
    }
}


// Reciplease/Screens/Detail/DetailModuleFactory.swift
//
//  DetailModuleFactory.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import UIKit

class DetailModuleFactory {
    class func makeModule(model: RecipeBO) -> DetailViewController {
        let view = DetailViewController()
        view.model = model
        return view
    }
}


// Reciplease/Screens/Detail/DetailView/Components/DetailMetaView.swift
//
//  DetailMetaView.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import UIKit

class DetailMetaView: UIView {
    
    private lazy var label: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .textSmall
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    private func setupUI() {
        
        // MARK: - Form
        layer.cornerRadius = 12
        layer.masksToBounds = true
        backgroundColor = .darkerCream
        label.textColor = .paleBrown
        
        // MARK: - Costraints
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    func setLabel(_ label: String) {
        self.label.text = label
    }
    
}


// Reciplease/Screens/Detail/DetailView/Components/FavoriteButton.swift
//
//  FavoriteButton.swift
//  Reciplease
//
//  Created by Cristian Rojas on 22/05/2021.
//

import UIKit

class FavoriteButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private var isFavorite: Bool = false {
        didSet {
            setupState()
        }
    }
    
    func setState(favorite: Bool) {
        isFavorite = favorite
    }
    
    private func setupState() {
        isFavorite ? setFavoriteUI() : setNotFavoriteUI()
    }
    
    func toggle() {
        isFavorite.toggle()
    }
    
    private func setFavoriteUI() {
        setImage(UIImage(named: "icHeartFilled")!, for: .normal)
        tintColor = .red
    }
    
    private func setNotFavoriteUI() {
        setImage(UIImage(named: "icHeart"), for: .normal)
        tintColor = .darkPurple
    }
}


// Reciplease/Screens/Detail/DetailView/Components/RecipeMetaDataView.swift
//
//  RecipeMetaDataView.swift
//  Reciplease
//
//  Created by Cristian Rojas on 30/05/2021.
//

import UIKit

class RecipeMetaDataView: UIStackView {
    
    private lazy var timeView: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .textSmall
        return view
    }()
    
    private lazy var yieldView: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .textSmall
        return view
    }()
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .paleBrown50
        layer.cornerRadius = 4
               
        addArrangedSubview(timeView)
        addArrangedSubview(yieldView)
    }
    
    func hideTimeLabel() {
        timeView.isHidden = true
    }
    
    func hideYieldLabel() {
        yieldView.isHidden = true
    }
    
    func setTimeLabel(_ time: Int) {
        timeView.text = "⏱" + " " + "\(time)"
    }
    
    func setYieldLabel(_ yield: Int) {
        yieldView.text = "👍" + " " + "\(yield)"
    }
}


// Reciplease/Screens/Detail/DetailView/DetailView.swift
//
//  DetailView.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Alamofire
import CoreData
import UIKit

class DetailView: UIView {
    
    lazy var picture: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .cream
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.font = .textBiggest
        view.numberOfLines = 0
        view.textColor = .darkPurple
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var favoriteButton: FavoriteButton = {
        let view = FavoriteButton()
        view.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var totalTimeView: DetailMetaView = {
        let view = DetailMetaView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var ingredientsTableView: UITableView = {
        let view = UITableView()
        view.backgroundView = nil
        view.backgroundColor = .clear
        view.tableFooterView = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var ingredientsLabel: UILabel = {
        let view = UILabel()
        view.font = .textMedium
        view.textColor = .darkPurple
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var getButton: DefaultButton = {
        let view = DefaultButton()
        view.addTarget(self, action: #selector(getButtonPressed), for: .touchUpInside)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var informationStackView: RecipeMetaDataView = {
        let view = RecipeMetaDataView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = UIStackView.spacingUseSystem
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return view
    }()
    
    var model: RecipeBO!
    var delegate: DetailViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
}

private extension DetailView {
    
    @objc
    func favoriteButtonPressed() {
        delegate?.didTapFavoriteButton(model)
    }
    
    @objc
    func getButtonPressed() {
        delegate?.didTapGetDirectionButton()
    }
}


// Reciplease/Screens/Detail/DetailView/DetailView+commonInit.swift
//
//  DetailView+setupUI.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import UIKit

// MARK: - UI methods
extension DetailView {
    func commonInit() {
        backgroundColor = .red
        setupConstraints()
        ingredientsTableView.showsVerticalScrollIndicator = false
    }
    
    func setupConstraints() {
        addSubview(picture)
        picture.image = UIImage(named: "recipe-placeholder")!
        NSLayoutConstraint.activate([
            picture.topAnchor.constraint(equalTo: topAnchor),
            picture.leadingAnchor.constraint(equalTo: leadingAnchor),
            picture.trailingAnchor.constraint(equalTo: trailingAnchor),
            picture.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4)
        ])
        
        addSubview(contentView)
        contentView.layer.cornerRadius = 44
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: picture.bottomAnchor, constant: -40),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        addSubview(favoriteButton)
        NSLayoutConstraint.activate([
            favoriteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            favoriteButton.heightAnchor.constraint(equalToConstant: 24),
            favoriteButton.widthAnchor.constraint(equalToConstant: 24)
        ])
        
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: favoriteButton.trailingAnchor, constant: -8)
        ])
        
        addSubview(getButton)
        NSLayoutConstraint.activate([
            getButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            getButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            getButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            getButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        contentView.addSubview(ingredientsTableView)
        NSLayoutConstraint.activate([
            ingredientsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            ingredientsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            ingredientsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            ingredientsTableView.bottomAnchor.constraint(equalTo: getButton.topAnchor)
        ])
        
        addSubview(informationStackView)
        NSLayoutConstraint.activate([
            informationStackView.bottomAnchor.constraint(equalTo: contentView.topAnchor, constant: -12),
            informationStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
       
        ])
    }
}


// Reciplease/Screens/Detail/DetailView/DetailView+setValues.swift
//
//  DetailView+setValues.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Alamofire
import CoreData
import UIKit

extension DetailView {
    
    func setTableViewController(_ delegateAndDataSource: UITableViewDelegate & UITableViewDataSource) {
        ingredientsTableView.delegate = delegateAndDataSource
        ingredientsTableView.dataSource = delegateAndDataSource
    }
    
    func set(model: RecipeBO) {
        self.model = model
        setPicture(with: model)
        setTitleLabel(model.label)
        setButtonLink(model.shareAs)
        setButtonTitle(S.getDirections)
        setTimeCountLabel(model.totalTime)
        setYieldLabel(model.yield)
        setFavoriteState(model.isFavorite)
    }
    
    func setFavoriteState(_ favorite: Bool) {
        favoriteButton.setState(favorite: favorite)
    }
    
    private func setPicture(with model: RecipeBO) {
        if let cachedData = cacheManager.recipeImages[model.label],
           let image = UIImage(data: cachedData) {
            picture.image = image
        } else {
            setPicture(with: model.image, and: model.label)
        }
    }
    
    private func setPicture(with url: String, and label: String) {
        
        AF.request(url, method: .get).response{ response in
            
            switch response.result {
            case .success(let responseData):
                
                guard
                    let safeData = responseData,
                    let image = UIImage(data: safeData) else
                {
                    return
                }
                
                cacheManager.recipeImages[label] = safeData
                self.picture.image = image
                
            case .failure(let error):
                /// @nth
                print("error--->",error)
            }
        }
    }
    
    private func setButtonLink(_ url: String) { }
    private func setButtonTitle(_ title: String) {
        getButton.setTitle(title, for: .normal)
    }
    
    private func setTitleLabel(_ label: String) {
        titleLabel.text = label
    }
    
    private func setIngredientsLabel(_ label: String) {
        ingredientsLabel.text = label
    }
    
    private func setTimeCountLabel(_ time: Int) {
        informationStackView.setTimeLabel(time)
        if time == 0 {
            informationStackView.hideTimeLabel()
        }
        
    }
    
    private func setYieldLabel(_ yield: Int) {
        informationStackView.setYieldLabel(yield)
        if yield == 0 {
            informationStackView.hideYieldLabel()
        }
    }
}


// Reciplease/Screens/Detail/DetailViewController.swift
//
//  DetailViewController.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 17/04/2021.
//

import Alamofire
import CoreData
import UIKit
import SafariServices


protocol DetailViewDelegate {
    func didTapFavoriteButton(_ checkModel: RecipeBO)
    func didTapGetDirectionButton()
}

protocol DetailViewControllerDelegate: AnyObject {
    func detailsViewControllerDidDelete(recipe: RecipeBO)
}

class DetailViewController: UIViewController {
    
    private lazy var rootView: DetailView = {
        let view = DetailView()
        view.delegate = self
        return view
    }()
    
    var model: RecipeBO!
    weak var delegate: DetailViewControllerDelegate?
    
    lazy var stack = CoreDataStack()
    lazy var managedObject = stack.mainContext
    lazy var coredataManager = RecipesCoredataManager(stack: stack, managedObject: managedObject)
    
    override func loadView() {
        view = rootView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.set(model: model)
        rootView.setTableViewController(self)
        setupNavbar()
    }
    
    private func setupNavbar() {
        navigationController?.navigationBar.prefersLargeTitles = false
    }
}

extension DetailViewController: DetailViewDelegate {
    
    func didTapFavoriteButton(_ model: RecipeBO) {
        if model.isFavorite {
            
            guard let coredataRecipes = coredataManager.storedRecipes() else { return }
            
            guard let recipe = coredataRecipes
                    .filter({ $0.url == model.url })
                    .first else
            {
                showAlert(message: S.errorAddingToFavoritres)
                return
            }
            coredataManager.delete(recipe: recipe)
            delegate?.detailsViewControllerDidDelete(recipe: model)
        } else {
            coredataManager.add(recipe: model)
        }
        
    
        rootView.favoriteButton.toggle()
    }
    
    func didTapGetDirectionButton() {
        if let safeURL = URL(string: model.shareAs) {
               let config = SFSafariViewController.Configuration()
               config.entersReaderIfAvailable = true

            let vc = SFSafariViewController(url: safeURL, configuration: config)
               present(vc, animated: true)
           }
    }
}

extension DetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        model.ingredients.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let cellModel = model.ingredients
        cell.textLabel?.text = cellModel[indexPath.row]
        cell.backgroundColor = .clear
        cell.textLabel?.font = .textMedium
        cell.textLabel?.textColor = .darkPurple
        cell.selectionStyle = .none
        
        return cell
    }
}


// Reciplease/Screens/List/Components/RecipeTableViewCell.swift
//
//  RecipeCell.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 16/04/2021.
//

import Alamofire
import UIKit


class RecipeTableViewCell: UITableViewCell {
    
    static let identifier: String = "RecipeCell"
    
    @IBOutlet weak var picture: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var likeCountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var timeView: UIView!
    
    override func layoutSubviews() {
        setupUI()
    }
    
    
    func configure(model: RecipeBO) {
        
        titleLabel.text = model.label
        timeLabel.text = "\(model.totalTime) MIN"
        likeCountLabel.text? = "👍 \(model.yield)"
       
        if model.totalTime == 0 {
            timeView.isHidden = true
        }
        
    }
    
    func set(image: UIImage) {
        picture.image = image
    }
    
    func setImage(with url: String, and label: String) {
        
        AF.request(url, method: .get).response { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let responseData):
    
                guard
                    let safeData = responseData,
                    let safeImage = UIImage(data: safeData)
                else {
                    self.set(image: UIImage(named: "recipe-placeholder")!)
                    return
                }
                
                cacheManager.recipeImages[label] = safeData
                self.set(image: safeImage)
               
                
            case .failure(let error):
                self.set(image: UIImage(named: "recipe-placeholder")!)
                #if DEBUG
                print(error)
                #endif
            }
        }
    }
    
    private func setupUI() {
        
        layer.cornerRadius = 28
        layer.masksToBounds = true
        backgroundColor = .brightSalmon
        
        picture.layer.cornerRadius = 28
        picture.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        
        titleLabel.font = .textBiggest
        likeCountLabel.font = .textMedium
//        timeLabel.font = .textSmall
        
        titleLabel.textColor = .darkPurple
        likeCountLabel.textColor = .darkPurple
        timeLabel.textColor =  .darkPurple
        
        timeView.layer.cornerRadius = 12
    }
    
}


// Reciplease/Screens/List/ListModuleFactory.swift
//
//  ListModuleFactory.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import Foundation

class ListModuleFactory {
    class func makeModule(model: [RecipeBO], type: ListType) -> ListViewController {
        let view = ListViewController.controllerFromStoryboard(.list)
        view.model = model
        view.type = type
        return view
    }
}


// Reciplease/Screens/List/ListViewController.swift
//
//  ListViewController.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import Alamofire
import UIKit

class ListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emtpyStateView: UIView!
    @IBOutlet weak var emptyStateImage: UIImageView!
    @IBOutlet weak var emptyLabel: UILabel!
    
    var model: [RecipeBO] = [ ]
    var type: ListType = .search
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupState()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
       
        setupType()
        setupTableView()
        setupNavigationBar()
        
        emptyLabel.font = .textMedium
        emptyLabel.textColor = .blood
        emtpyStateView.isHidden = true
    }
    
    /// Setups view state.
    /// If model is empty we should give feedback to the user
    private func setupState() {
        if model.isEmpty {
            tableView.isHidden = true
            emtpyStateView.isHidden = false
        } else {
            tableView.isHidden = false
            emtpyStateView.isHidden = true
        }
        
        tableView.reloadData()
    }
    
    private func setupType() {
        if type == .favorite {
            navigationItem.title = S.favorites
            emptyStateImage.image = UIImage(named: "empty-favorites")!
            emptyLabel.text = S.noFavoritesYet + "\n" + S.howToFavorites
        } else {
            navigationItem.title = S.results
            emptyStateImage.image = UIImage(named: "empty-search")!
            emptyLabel.text = S.noResultsFound
        }
    }
    
    private func setupTableView() {
        tableView.backgroundView = nil
        tableView.backgroundColor = .clear
        tableView.separatorColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.tintColor = UIColor.darkPurple
        
        navigationController?.navigationBar.largeTitleTextAttributes =
            [NSAttributedString.Key.foregroundColor: UIColor.darkPurple,
             NSAttributedString.Key.font: UIFont.textBiggest]
    
        navigationController?.navigationBar.barTintColor = .cream
        navigationController?.navigationBar.shadowImage = UIImage()
    }
}

// MARK:- Table View Delegate
extension ListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        guard
            let model = model.getOrNull(at:indexPath.section),
            let cell = tableView.dequeueReusableCell(withIdentifier: RecipeTableViewCell.identifier, for: indexPath) as? RecipeTableViewCell
        else {
            return UITableViewCell()
        }
        
        if
            let cachedData = cacheManager.recipeImages[model.label],
            let image = UIImage(data: cachedData) {
            
            cell.set(image: image)
        } else {
            cell.setImage(with: model.image, and: model.label)
        }
        
        cell.configure(model: model)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        180
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        model.count
    }
    
    // There is just one row in every section
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    // Set the spacing between sections
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        28
    }
    
    // Make the background color show through
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView
    }
    
    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let view = DetailModuleFactory.makeModule(model: model[indexPath.section])
        view.delegate = self
        router?.push(view)
    }
}

extension ListViewController: DetailViewControllerDelegate {
    func detailsViewControllerDidDelete(recipe: RecipeBO) {
        model.removeAll { $0.url == recipe.url }
        tableView.reloadData()
    }
}


// Reciplease/Screens/Search/Components/CollectionView/TagCollectionViewCell.swift
//
//  TagCollectionViewCell.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 04/04/2021.
//

import UIKit

class TagCollectionViewCell: UICollectionViewCell {
    @IBOutlet var tagLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        
        // MARK: - Background
        layer.cornerRadius = 20
        layer.masksToBounds = true
        backgroundColor = .brightSalmon
        
        // MARK: - Label
        tagLabel.font = .textSmall
        tagLabel.textColor = .blood
    }
}


// Reciplease/Screens/Search/Components/CollectionView/TagFlowLayout.swift
//
//  TagFlowLayout.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import UIKit

class Row {
    var attributes = [UICollectionViewLayoutAttributes]()
    var spacing: CGFloat = 0

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func add(attribute: UICollectionViewLayoutAttributes) {
        attributes.append(attribute)
    }

    func tagLayout(collectionViewWidth: CGFloat) {
        let padding = 10
        var offset = padding
        for attribute in attributes {
            attribute.frame.origin.x = CGFloat(offset)
            offset += Int(attribute.frame.width + spacing)
        }
    }
}

class TagFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }

        var rows = [Row]()
        var currentRowY: CGFloat = -1

        for attribute in attributes {
            if currentRowY != attribute.frame.origin.y {
                currentRowY = attribute.frame.origin.y
                rows.append(Row(spacing: 10))
            }
            rows.last?.add(attribute: attribute)
        }

        rows.forEach { $0.tagLayout(collectionViewWidth: collectionView?.frame.width ?? 0) }
        return rows.flatMap { $0.attributes }
    }
}


// Reciplease/Screens/Search/Components/SearchButton.swift
//
//  SearchButton.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 04/04/2021.
//

import UIKit

@IBDesignable
class SearchButton: UIButton {
    
    private var activityIndicator = FoodActivityIndicator()
    
    var isLoading: Bool = false {
        didSet {
            isEnabled = !isLoading
            handleLoadingState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupButton()
    }
    
    private func handleLoadingState() {
        if isLoading {
            activityIndicator.startAnimating()
            clearIcon()
            setTitleColor(.clear, for: .normal)
        } else {
            activityIndicator.stopAnimating()
            setupIcon()
            setTitleColor(.white, for: .normal)
        }
    }
    
    private func setupButton() {

        setTitleColor(.white, for: .normal)
        setTitleColor(.white, for: .highlighted)
        setTitleColor(.white, for: .selected)
        layer.cornerRadius = frame.height / 2
        titleLabel?.font = .textMedium
        backgroundColor = .strongSalmon
        
        setupIcon()
        setupIndicator()
    }
    
    private func setupIndicator() {
        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            activityIndicator.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupIcon() {
        let icon = UIImage(named: "icSearchButton")!.withRenderingMode(.alwaysOriginal)
        setImage(icon, for: .normal)
        imageView?.contentMode = .scaleAspectFit
        imageEdgeInsets = UIEdgeInsets(top: 0, left: -20, bottom: 0, right: 0)

    }
    
    private func clearIcon() {
        let icon = UIImage()
        setImage(icon, for: .normal)
    }
}


// Reciplease/Screens/Search/SearchVC+CollectionView.swift
//
//  SearchVC+CollectionView.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 04/04/2021.
//

import UIKit

extension SearchViewController:
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCollectionViewCell", for: indexPath) as? TagCollectionViewCell
        else {
            return TagCollectionViewCell()
        }
        
        
        if let value = FoodEmojis.model[dataSource[indexPath.row]] {
            cell.tagLabel.text = value + " " + dataSource[indexPath.row]
        } else {
            cell.tagLabel.text = dataSource[indexPath.row]
        }
       
        cell.tagLabel.preferredMaxLayoutWidth = collectionView.frame.width - 32
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        dataSource.remove(at: indexPath.item)
        collectionView.reloadData()
        
    }
}


// Reciplease/Screens/Search/SearchVC+SetupUI.swift
//
//  SearchVC+SetupUI.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 28/03/2021.
//

import UIKit

extension SearchViewController {
    
    func setupUI() {
        
        setupCollectionView()
        
        subHeadingLabel.text = S.searchSubHeading
        subHeadingLabel.font = .textMedium
        subHeadingLabel.textColor = .darkPurple
        
        ingredientsLabel.text = S.searchIngredientList
        ingredientsLabel.font = .textBig
        ingredientsLabel.textColor = .darkPurple
        
        clearButton.imageEdgeInsets = UIEdgeInsets.same(with: 18)
        clearButton.backgroundColor = .pink
        clearButton.tintColor = .blood
        clearButton.layer.cornerRadius = 52 / 2
        clearButton.layer.masksToBounds = true
        
        
        searchBarView.backgroundColor = .darkerCream
        searchBarView.layer.cornerRadius = 26
        
        
        appendButton.layer.cornerRadius = 22
        appendButton.layer.masksToBounds = true
        searchTextField.delegate = self
        searchTextField.font = UIFont.textMedium
        searchTextField.textColor = .darkPurple
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: S.searchPlaceholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.paleBrown,
                NSAttributedString.Key.font: UIFont.textSmall
            ])
        
        searchButton.setTitle(S.search, for: .normal)
        
        setupNavbar()
        setupIngredientsSection()
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        let layout = TagFlowLayout()
        layout.estimatedItemSize = CGSize(width: 140, height: 40)
        collectionView.collectionViewLayout = layout
    }
    
    private func setupNavbar() {

        navigationItem.title = S.searchHeading
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Clears shadow
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.barTintColor = UIColor.cream50
        navigationController?.navigationBar.largeTitleTextAttributes =
            [NSAttributedString.Key.foregroundColor: UIColor.darkPurple,
             NSAttributedString.Key.font: UIFont.textBiggest]
    }
    
    func setupIngredientsSection() {
        if dataSource.isEmpty {
            hideIngredientSection()
        } else {
            showIngredientSection()
        }
    }
    
    private func hideIngredientSection() {
        ingredientsSectionHeader.isHidden = true
        collectionView.isHidden = true
        searchButton.isHidden = true
        clearButton.isHidden = true
    }
    
    private func showIngredientSection() {
        ingredientsSectionHeader.isHidden = false
        clearButton.isHidden = false
        collectionView.isHidden = false
        searchButton.isHidden = false
    }
}

extension SearchViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        UIView.animate(withDuration: 0.4) {
            self.searchBarView.backgroundColor = .white
            self.searchBarView.layer.shadowColor = UIColor.black.cgColor
            self.searchBarView.layer.shadowOpacity = 0.2
            self.searchBarView.layer.shadowOffset = .zero
            self.searchBarView.layer.shadowRadius = 2
            
            self.searchTextField.attributedPlaceholder = NSAttributedString(
                string: S.searchPlaceholder,
                attributes: [
                    NSAttributedString.Key.font: UIFont.textMedium
                ])
            
            self.appendButton.backgroundColor = .deepGreen
            self.appendButton.tintColor = .white
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.4) {
            self.searchBarView.backgroundColor = .darkerCream
            self.searchBarView.layer.shadowColor = UIColor.clear.cgColor
            self.searchTextField.attributedPlaceholder = NSAttributedString(
                string: S.searchPlaceholder,
                attributes: [
                    NSAttributedString.Key.font: UIFont.textSmall
                ])
            
            self.appendButton.backgroundColor = .pink
            self.appendButton.tintColor = .blood
        }
        
    }
}


// Reciplease/Screens/Search/SearchViewController.swift
//
//  SearchViewController.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import UIKit

class SearchViewController: UIViewController {
    
    @IBOutlet weak var subHeadingLabel: UILabel!
    @IBOutlet weak var searchTextField: UITextField! {
        didSet { searchTextField.addDoneToolbar() }
    }
    
    @IBOutlet weak var searchBarView: UIView!
    @IBOutlet weak var appendButton: UIButton!
    @IBOutlet weak var ingredientsSectionHeader: UIStackView!
    @IBOutlet weak var ingredientsLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchButton: SearchButton!
    
    
    private lazy var repository: RecipesRepositoryInput = {
        let repo = RecipesRepository()
        repo.output = self
        return repo
    }()
    

    lazy var stack = CoreDataStack()
    lazy var managedObject = stack.mainContext
    lazy var coredataManager = RecipesCoredataManager(stack: stack, managedObject: managedObject)
    
    var dataSource: [String] = [] {
        didSet {
            setupIngredientsSection()
        }
    }
    
    var api: RecipleaseApiInput = RecipleaseApi()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }

    
    @IBAction func appendButtonPressed(_ sender: Any) {
        guard
            let safeIngredients = searchTextField.text?.replacingOccurrences(of: " ", with: "")
        else {
            dismissKeyboard()
            showAlert(message: S.errorUnknown)
            return
        }
        
        guard !safeIngredients.isEmpty else {
            dismissKeyboard()
            showAlert(message: S.errorEmptyIngredients)
            return
        }
        
        let ingredients = safeIngredients.components(separatedBy: ",")
        
        dataSource.append(contentsOf: ingredients)
        dataSource = dataSource.filterDuplicates()
        dismissKeyboard()
        searchTextField.text = ""
        collectionView.reloadData()
    }
        
    @IBAction func clearButtonPressed(_ sender: Any) {
        dataSource = [ ]
        collectionView.reloadData()
    }
    
    @IBAction func searchButtonPressed(_ sender: Any) {
        searchButton.isLoading = true
        let query = dataSource.joined(separator: "+")
        repository.performSearch(query: query)
    }
}

extension SearchViewController: RecipesRepositoryOutput {
    func didPerformSearch(_ result: Result<RecipeResponse, Error>) {
        switch result {
        case .success(let response):
            didUpdate(state: .success(response))
        case .failure(_):
            didUpdate(state: .error)
        }
    }
    
    func didUpdate(state: SearchViewState) {
        searchButton.isLoading = state.isLoading
        switch state {
        case .success(let response):
            
            guard let coredataRecipes = coredataManager.storedRecipes() else { return }
            
            let recipesBO: [RecipeBO] = response.recipes.map { recipe in
                    let isFavorite = coredataRecipes.contains{ $0.url == recipe.url }
                    return RecipeBO(recipe: recipe, isFavorite: isFavorite)
                }
            
            router?.push(ListModuleFactory.makeModule(model: recipesBO, type: .search))
        case .error:
            showAlert(message: S.errorNetwork)
        default: break
        }
    }
}


// Reciplease/Screens/Tabbar/TabbarViewController.swift
//
//  ViewController.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 20/03/2021.
//
import CoreData
import UIKit

class TabbarViewController: UITabBarController {
    
    lazy var stack = CoreDataStack()
    lazy var managedObject = stack.mainContext
    lazy var coredataManager = RecipesCoredataManager(stack: stack, managedObject: managedObject)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
    }
}

// MARK: - TabbarController Delegate
extension TabbarViewController: UITabBarControllerDelegate {
    
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
       
        if
            let navigationController = viewController as? UINavigationController,
            let safeFavoritesViewController = navigationController.viewControllers.first as? ListViewController
            {
            injectCoreDataModel(into: safeFavoritesViewController)
        }
    }
    
    /// CoreData dependency injection into the Favorites Screen.
    /// Needed because we're using the same viewController to show search results
    private func injectCoreDataModel(into viewController: ListViewController) {
        
        
        guard let coreDataRecipes = coredataManager.storedRecipes() else { return }
         
        let model: [RecipeBO] = coreDataRecipes.map { RecipeBO(recipe: $0) }
        
        viewController.type = .favorite
        viewController.model = model
        
    }
}


// Reciplease/Screens/Tabbar/ViewController.swift
//
//  ViewController.swift
//  Reciplease
//
//  Created by Cristian Rojas on 20/03/2021.
//

import Alamofire
import UIKit

class TabbarViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}



// Reciplease/UI/DefaultButton.swift
//
//  DefaultButton.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 01/05/2021.
//

import UIKit

class DefaultButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .pink
        titleLabel?.font = .textMedium
        titleLabel?.textColor = .blood
        layer.cornerRadius = frame.height / 2
        layer.masksToBounds = true
    }
}


// Reciplease/UI/FoodActivityIndicator.swift
//
//  Loader.swift
//  Reciplease
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import UIKit

@IBDesignable
class FoodActivityIndicator: UIView {
    
    private let emojiLabel = UILabel()
    private var timer: Timer?
    private var index = 0
    
    var hidesWhenStopped: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupButton()
    }
    
    private func setupButton() {
        
        backgroundColor = .clear
        
        setupLabel()
    }
    
    private func setupLabel() {
        addSubview(emojiLabel)
        emojiLabel.font = emojiLabel.font.withSize(24)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            emojiLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        ])
    }
    
    func startAnimating() {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        if hidesWhenStopped { self.isHidden = false }
    }
    
    func startRotating() {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = -Double.pi * 2
        rotateAnimation.duration = 1.0
        rotateAnimation.repeatCount = .infinity
        
        emojiLabel.layer.add(rotateAnimation, forKey: nil)
    }
    
    func stopAnimating() {
        timer?.invalidate()
        if hidesWhenStopped { self.isHidden = true }
    }

    @objc
    func fireTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let emoji = FoodEmojis.allCases.getOrNull(at: self.index) {
                self.index += 1
                self.emojiLabel.text = emoji.rawValue
            } else {
                self.index = 0
                self.emojiLabel.text = FoodEmojis.allCases[self.index].rawValue
            }
        }
    }
}


// RecipleaseTests/Data/CoreData/RecipesCoredataManagerTests.swift
//
//  RecipleaseCoredataManagerTests.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 17/05/2021.
//

import CoreData
import XCTest
@testable import Reciplease

class RecipesCoredataManagerTests: XCTestCase {
    
    var coreDataStack: CoreDataStack!
    var manager: RecipesCoredataManager!
    
    override func setUp() {
        super.setUp()
        coreDataStack = TestCoreDataStack()
        manager = RecipesCoredataManager(
            stack: coreDataStack,
            managedObject: coreDataStack.mainContext
        )
    }
    
    override func tearDown() {
        coreDataStack = nil
        manager = nil
    }
    
    func testAddRecipe() {
        
        let newRecipe = RecipeBO(
            recipe: Recipe(
                uri: "",
                label: "",
                image : "",
                source: "",
                url: "",
                shareAs: "",
                yield: 10,
                ingredients: [],
                totalTime: 0),
            isFavorite: false)
        
        manager.add(recipe: newRecipe)
    }
    
    func testRootContextIsSavedAfterAddingReport() {
        
        let derivedContext = coreDataStack.newDerivedContext()
        
        manager = RecipesCoredataManager(
            stack: coreDataStack,
            managedObject: derivedContext
        )
        
        expectation(
            forNotification: .NSManagedObjectContextDidSave,
            object: coreDataStack.mainContext
        ) { _ in
            return true
        }
        
        derivedContext.perform {
            self.manager.add(recipe:
                                RecipeBO(
                                    recipe: Recipe(
                                        uri: "",
                                        label: "",
                                        image : "",
                                        source: "",
                                        url: "",
                                        shareAs: "",
                                        yield: 10,
                                        ingredients: [],
                                        totalTime: 0),
                                    isFavorite: false))
        }
        
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Save did not occur")
        }
    }
    
    func testFetchRecipes() {
        
        let recipe = Recipe(
            uri: "\(UUID())",
            label: "Paella",
            image : "",
            source: "",
            url: "",
            shareAs: "",
            yield: 0,
            ingredients: [],
            totalTime: 0
        )
        
        let newRecipe = RecipeBO(recipe: recipe, isFavorite: false)
        self.manager.add(recipe: newRecipe)
        
        let fetchedRecipes = manager.storedRecipes()
        
        XCTAssertNotNil(fetchedRecipes)
        XCTAssertTrue(fetchedRecipes?.count == 1)
        XCTAssertTrue(recipe.uri == fetchedRecipes?.first?.uri)
        XCTAssertTrue(recipe.label == fetchedRecipes?.first?.label)
    }
    
    func testDeleteRecipe() {
     
        let recipe = Recipe(
            uri: "\(UUID())",
            label: "",
            image : "",
            source: "",
            url: "",
            shareAs: "",
            yield: 0,
            ingredients: [],
            totalTime: 0
        )
        
        let newRecipe = RecipeBO(recipe: recipe, isFavorite: false)
        self.manager.add(recipe: newRecipe)
        
        var fetchedRecipes = manager.storedRecipes()
        XCTAssertTrue(fetchedRecipes?.count == 1)
        XCTAssertTrue(recipe.uri == fetchedRecipes?.first?.uri)
        
        manager.delete(recipe: fetchedRecipes!.first!)
        
        fetchedRecipes = manager.storedRecipes()
        
        XCTAssertTrue(fetchedRecipes?.isEmpty ?? false)
    }
}


// RecipleaseTests/Data/CoreData/TestCoreDataStack.swift
//
//  CoreDataTests.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 17/05/2021.
//

import CoreData
@testable import Reciplease

class TestCoreDataStack: CoreDataStack {
  override init() {
    super.init()

    
    /// Creates an in-memory persistent store
    let persistentStoreDescription = NSPersistentStoreDescription()
    persistentStoreDescription.type = NSInMemoryStoreType

    
    let container = NSPersistentContainer(
      name: CoreDataStack.modelName,
      managedObjectModel: CoreDataStack.model)

    container.persistentStoreDescriptions = [persistentStoreDescription]

    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    storeContainer = container
  }
}


// RecipleaseTests/Data/Repository/Dependencies/MockRecipeApi.swift
//
//  MockRecipeApi.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 22/05/2021.
//

import Foundation
@testable import Reciplease

class MockRecipeApi: RecipleaseApiInput {

    var withError = false
    static let mockResponse: RecipeResponse = RecipeResponse(recipes: [])

    func getSearch(query: String, completion: @escaping (Result<RecipeResponse, Error>) -> Void) {
        if withError {
            completion(.failure(Error(type: .networkError)))
        } else {
            completion(.success(MockRecipeApi.mockResponse))
        }
    }
}


// RecipleaseTests/Data/Repository/Dependencies/MockRecipesRepositoryOutput.swift
//
//  MockRecipesRepositoryOutput.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 22/05/2021.
//

import Foundation
@testable import Reciplease

class MockRecipesRepositoryOutput: RecipesRepositoryOutput {
    var result: Result<RecipeResponse, Error>?
    var states: [SearchViewState] = []

    func didUpdate(state: SearchViewState) {
        states.append(state)
    }

    func didPerformSearch(_ result: Result<RecipeResponse, Error>) {
        self.result = result
        switch result {
        case .success(let response):
            didUpdate(state: .success(response))
        case .failure(_):
            didUpdate(state: .error)
        }
    }
}


// RecipleaseTests/Data/Repository/RecipesRepositoryTests.swift
//
//  RecipesRepositoryTests.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 05/04/2021.
//

import XCTest
@testable import Reciplease

class RecipesRepositoryTests: XCTestCase {
    
    /// SUT dependences
    var api: MockRecipeApi!
    var output: MockRecipesRepositoryOutput!
    
    /// SUT protocol
    var sut: RecipesRepositoryInput!

    override func setUp() {
        
        /// SUT Dependencies
        api = MockRecipeApi()
        output = MockRecipesRepositoryOutput()
        
        /// SUT  object
        sut = RecipesRepository(api: api)
        sut.output = output
    }

    override func tearDown() {
        api = nil
        output = nil
        sut = nil
    }
    
    func testPerformResearch_WithSuccess() {
        sut.performSearch(query: "")
        if case .success = output.result {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }

    func testPerformSearch_WithFailure() {
        api.withError = true
        sut.performSearch(query: "")
        if case .failure = output.result {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testPerformResearch_WithSuccess_SetsSuccessState() {
        sut.performSearch(query: "test")
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .success(MockRecipeApi.mockResponse))
    }
    
    func testPerformResearch_WithFailure_SetsErrorState() {
        api.withError = true
        sut.performSearch(query: "")
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .error)
    }
}


// RecipleaseTests/Extensions/UIColorTests.swift
//
//  UIColor.swift
//  RecipleaseTests
//
//  Created by Cristian Felipe Patiño Rojas on 27/03/2021.
//

import XCTest
@testable import Reciplease

class UIColorTests: XCTestCase {
    
    func testColors() {
        XCTAssertNotEqual(UIColor.salmon, nil)
        XCTAssertNotEqual(UIColor.cream, nil)
        XCTAssertNotEqual(UIColor.darkPurple, nil)
    }
}



// p5-baluchon.swift

// Baluchon/Application/AppDelegate.swift
//
//  AppDelegate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // Needed for iOS 12 and earlier versions
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        setupTabBar()
        return true
    }

    // MARK: UISceneSession Lifecycle
    @available(iOS 13, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    @available(iOS 13, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        postWillEnterForegroundNotification()
    }
    
    func postWillEnterForegroundNotification() {
        NotificationCenter.default.post(name: .willEnterForeground, object: nil)
    }
}

// MARK: - Private
private extension AppDelegate {
    func setupTabBar() {
        let appearance = UITabBar.appearance()
        
        
        appearance.backgroundColor = .azure
    
        appearance.shadowImage =  UIImage.getShadow()
        appearance.backgroundImage = UIImage()
        
        appearance.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.4)
        
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
        ]
        
        UITabBar.appearance().tintColor = .white
        UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .normal)
    }
}


// Baluchon/Application/SceneDelegate.swift
//
//  SceneDelegate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import UIKit

@available(iOS 13, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}



// Baluchon/Data/Registry/Registry.swift
//
//  Registry.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import Foundation

enum Registry {
    static let defaults = UserDefaults.standard
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: .fetchingDate)
        UserDefaults.standard.removeObject(forKey: .exchangeRate)
    }
}

extension String {
    static let exchangeRate = "exchangeRate"
    static let fetchingDate = "fetchingDate"
}


// Baluchon/Data/Repository/ExchangeRepository.swift
//
//  ExchangeRepository.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

protocol ExchangeRepositoryOutput: class {
    func didFetchExchange(result: Result<ExchangeResponse, Error>)
    func didUpdate(state: ExchangeViewState)
}

protocol ExchangeRepositoryInput {
    func fetchExchange()
    var output: ExchangeRepositoryOutput? { get set }
}

class ExchangeRepository: ExchangeRepositoryInput {
    
    weak var output: ExchangeRepositoryOutput?
    private let api: FixerApiInput
    
    init(api: FixerApiInput) {
        self.api = api
    }
    
    func fetchExchange() {
        output?.didUpdate(state: .loading)
        api.getRate { [weak self] result in
            self?.output?.didFetchExchange(result: result)
        }
    }
}


// Baluchon/Data/Repository/TranslationRepository.swift
//
//  TranslationRepository.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

protocol TranslationRepositoryOutput: class {
    func didFetchTranslation(result: Result<TranslationResponse, Error>)
    func didUpdate(state: TranslationViewState)
}

protocol TranslationRepositoryInput {
    func fetchTranslation(query: String)
    var output: TranslationRepositoryOutput? { get set }
}

class TranslationRepository: TranslationRepositoryInput {
    
    weak var output: TranslationRepositoryOutput?
    var api: GoogleTranslateApiInput?
    
    init(api: GoogleTranslateApiInput) {
        self.api = api
    }
    
    func fetchTranslation(query: String) {
        output?.didUpdate(state: .loading)
        api?.getTranslation(query: query) { [weak self] result in
            self?.output?.didFetchTranslation(result: result)
        }
    }
}


// Baluchon/Data/Repository/WeatherRepository.swift
//
//  WeatherRepository.swift
//  Baluchon
//
//  Created by cris on 17/12/2020.
//

import Foundation

//typealias WeatherViewState = WeatherViewController.State

protocol WeatherRepositoryOutput: class {
    func didFetchLocalWeather(result: Result<WeatherResponse, Error>)
    func didFetchDestinationWeather(result: Result<WeatherResponse, Error>)
    func didUpdateDestination(state: WeatherViewState)
    func didUpdateLocal(state: WeatherViewState)
}

protocol WeatherRepositoryInput {
    func fetchWeather()
    func fetchDestinationWeather()
    func fetchLocalWeather()
    
    var api: OpenWeatherApiInput? { get set }
    var output: WeatherRepositoryOutput? { get set }
}

class WeatherRepository: WeatherRepositoryInput {
    
    weak var output: WeatherRepositoryOutput?
    var api: OpenWeatherApiInput?
    
    init(api: OpenWeatherApiInput) {
        self.api = api
    }
    
    func fetchWeather() {
        fetchLocalWeather()
        fetchDestinationWeather()
    }
    
    func fetchLocalWeather() {
        output?.didUpdateLocal(state: .loadingLocal)
        api?.getLocalWeather { [weak self] result in
            switch result {
            case .success(let response):
                self?.output?.didFetchLocalWeather(result: .success(response))
            case .failure(let error):
                self?.output?.didFetchLocalWeather(result: .failure(error))
            }
        }
    }
    
    func fetchDestinationWeather() {
        output?.didUpdateDestination(state: .loadingDestination)
        api?.getDestinationWeather { [weak self] result in
            switch result {
            case .success(let response):
                self?.output?.didFetchDestinationWeather(result: .success(response))
            case .failure(let error):
                self?.output?.didFetchDestinationWeather(result: .failure(error))
            }
        }
    }
    
}


// Baluchon/Data/Services/Api.swift
//
//  Api.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

enum Api {
    static let googleTranslate = GoogleTranslateApi()
    static let fixer = FixerApi()
    static let openWeather = OpenWeatherApi()
}


// Baluchon/Data/Services/Fixer/Fixer.swift
//
//  Fixer.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import Foundation

enum Fixer {
    static let apiKey  = ""
    static let baseURL = "http://data.fixer.io/api/latest"

    case eurUSD
    case usdEUR
}

// MARK: - Router
extension Fixer {
    
    var url: URL? {
        switch self {
        case .eurUSD:
            return buildURL(from: "EUR", to: "USD")
        case .usdEUR:
            return buildURL(from: "USD", to: "EUR")
        }
    }
    
    private func buildURL(from: String, to: String) -> URL? {
        var components = URLComponents(string: Fixer.baseURL)!
        
        let queryItemToken = URLQueryItem(name: "access_key", value: Fixer.apiKey)
        let queryItemFrom = URLQueryItem(name: "base", value: from)
        let queryItemTo = URLQueryItem(name: "symbols", value: to)
        
        components.queryItems = [queryItemToken,
                                 queryItemFrom,
                                 queryItemTo]
        return components.url
    }
}


// Baluchon/Data/Services/Fixer/FixerApi.swift
//
//  FixerApi.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

protocol FixerApiInput {
    func getRate(completion: @escaping ((Result<ExchangeResponse, Error>) -> Void))
}

class FixerApi: FixerApiInput {
    
    func getRate(completion: @escaping ((Result<ExchangeResponse, Error>) -> Void)) {
        URLSession.decode(url: Fixer.eurUSD.url, into: ExchangeResponse.self, with: completion)
    }
}


// Baluchon/Data/Services/GoogleTranslate/GoogleTranslate.swift
//
//  GoogleTranslate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import Foundation

enum GoogleTranslate {
    
    static let apiKey  = ""
    static let baseURL = "https://translation.googleapis.com/language/translate/v2"
    
    case translate(query: String)
}


// MARK: - Router
extension GoogleTranslate {
    
    var url: URL? {
        switch self {
        case .translate(let query):
            return buildURL(query: query)
        }
    }
    
    func buildURL(query: String) -> URL? {
        var components = URLComponents(string: GoogleTranslate.baseURL)!
        
        let queryItemToken  = URLQueryItem(name: "key", value: GoogleTranslate.apiKey)
        let queryItemQuery  = URLQueryItem(name: "q", value: query)
        let queryItemTarget = URLQueryItem(name: "target", value: "en")
        
        components.queryItems = [queryItemToken,
                                 queryItemQuery,
                                 queryItemTarget]
        return components.url
    }
}


// Baluchon/Data/Services/GoogleTranslate/GoogleTranslateApi.swift
//
//  GoogleTranslateApi.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

protocol GoogleTranslateApiInput {
    func getTranslation(query: String, completion: @escaping ((Result<TranslationResponse, Error>) -> Void))
}

class GoogleTranslateApi: GoogleTranslateApiInput {
    func getTranslation(query: String, completion: @escaping ((Result<TranslationResponse, Error>) -> Void)) {
        let url = GoogleTranslate.translate(query: query).url
        URLSession.decode(url: url, into: TranslationResponse.self, with: completion)
    }
}


// Baluchon/Data/Services/OpenWeather/OpenWeather.swift
//
//  OpenWeathermap.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import Foundation

// MARK: - OpenWeatherMap Service
enum OpenWeather {
    static let apiKey  = ""
    static let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    case newYork
    case chartres
}

// MARK: - Router
extension OpenWeather {
    
    var url: URL? {
        switch self {
        case .newYork:
            return buildURL(with: "new+york")
        case .chartres:
            return buildURL(with: "chartres")
        }
    }
    
    private func buildURL(with city: String) -> URL? {
        var components = URLComponents(string: OpenWeather.baseURL)!

        let queryItemQuery = URLQueryItem(name: "q", value: city)
        let queryItemToken = URLQueryItem(name: "appid", value: OpenWeather.apiKey)
        let queryItemMode  = URLQueryItem(name: "mode", value: "json")
        let queryItemUnits = URLQueryItem(name: "units", value: "metric")
        let queryItemsLang = URLQueryItem(name: "lang", value: "fr")

        components.queryItems = [queryItemQuery,
                                 queryItemToken,
                                 queryItemMode,
                                 queryItemUnits,
                                 queryItemsLang]
        return components.url
    }
}


// Baluchon/Data/Services/OpenWeather/OpenWeatherApi.swift
//
//  OpenWeatherMapApi.swift
//  Baluchon
//
//  Created by cris on 17/12/2020.
//

import Foundation

protocol OpenWeatherApiInput {
    func getLocalWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void)
    func getDestinationWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void)
}

class OpenWeatherApi: OpenWeatherApiInput {
    
    func getLocalWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void) {
        URLSession.decode(url: OpenWeather.chartres.url, into: WeatherResponse.self, with: completion)
    }
    
    func getDestinationWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void) {
        URLSession.decode(url: OpenWeather.newYork.url, into: WeatherResponse.self, with: completion)
    }
}


// Baluchon/Domain/Model/Api/ExchangeResponse.swift
//
//  ExchangeResponse.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

struct ExchangeResponse: Decodable, Equatable {
    let rates: Rates
}


// Baluchon/Domain/Model/Api/TranslationResponse.swift
//
//  TranslationResponse.swift
//  Baluchon
//
//  Created by cris on 19/12/2020.
//

import Foundation

struct TranslationResponse: Decodable, Equatable {
    let data: TranslationData
}


// Baluchon/Domain/Model/Api/WeatherResponse.swift
//
//  WeatherResponse.swift
//  Baluchon
//
//  Created by cris on 18/12/2020.
//

import Foundation

struct WeatherResponse: Decodable, Equatable {
    let name: String
    let main: WeatherTemp
    let weather: [Weather]
}


// Baluchon/Domain/Model/Error.swift
//
//  NetworkError.swift
//  Baluchon
//
//  Created by cris on 17/12/2020.
//

import Foundation

enum ErrorType: Equatable {
    case invalidURL
    case noDataError
    case decodingError
    case networkError
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid url"
        case .noDataError:
            return "No data found"
        case .decodingError:
            return "Fail while decoding"
        case .networkError:
            return "Network error"
        }
    }
}

struct Error: Swift.Error {
    let type: ErrorType
}


// Baluchon/Domain/Model/Rates.swift
//
//  Rates.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/01/2021.
//
// MARK: - Rates
struct Rates: Decodable, Equatable {
    let usd: Float

    enum CodingKeys: String, CodingKey {
        case usd = "USD"
    }
}


// Baluchon/Domain/Model/Symbols.swift
//
//  Symbols.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import Foundation

enum Symbols {
    case eur
    case usd
    
    var string: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        }
    }
}


// Baluchon/Domain/Model/Translation.swift
//
//  Translation.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/01/2021.
//

// MARK: - DataClass
struct TranslationData: Decodable, Equatable {
    let translations: [Translation]
}

// MARK: - Translation
struct Translation: Decodable, Equatable {
    let translatedText: String
    let detectedSourceLanguage: String
}


// Baluchon/Domain/Model/Weather.swift
//
//  Weather.swift
//  Baluchon
//
//  Created by cris on 03/12/2020.
//

import Foundation

struct Weather: Decodable, Equatable {
    let id: Int
    let description: String
    
    var icon: String {
        switch id {
        case 200 ... 299:
            return "bolt"
        case 300 ... 399:
            return "drizzle"
        case 500 ... 599:
            return "rain"
        case 600 ... 699:
            return "snow"
        case 700 ... 799:
            return "fog"
        case 800:
            return "sun"
        case 801 ... 899:
            return "cloud"
        default:
            return  "unknown"
        }
    }
}


// Baluchon/Domain/Model/WeatherTemp.swift
//
//  WeatherTemp.swift
//  Baluchon
//
//  Created by cris on 18/12/2020.
//

import Foundation

struct WeatherTemp: Decodable, Equatable {
    let temp: Double
}


// Baluchon/Extension/Data+mapResponse.swift
//
//  Data+decode.swift
//  Baluchon
//
//  Created by cris on 17/12/2020.
//

import Foundation

extension Data {
    
    static let JSONdecoder = JSONDecoder()
    func mapResponse<T: Decodable>(into type: T.Type) -> T? {
        do {
            let data = try Data.JSONdecoder.decode(type, from: self)
            return data
        } catch {
            return nil
        }
    }
}


// Baluchon/Extension/Date+intervalGreatherThanDay.swift
//
//  Date+intervalGreatherThanDay.swift
//  Baluchon
//
//  Created by Cristian Rojas on 07/03/2021.
//

import Foundation

extension Date {
    func moreThanADay(from date: Date) -> Bool {
       
        /// Define a day interval in seconds = 24h * 60m * 60s
        let dayInterval: TimeInterval = 24 * 60 * 60
        
        /// Compare
        let interval = self.timeIntervalSince(date)
        
        return interval > dayInterval
    }
}


// Baluchon/Extension/NotificationName+values.swift
//
//  NotificationName+values.swift
//  Baluchon
//
//  Created by Cristian Rojas on 27/02/2021.
//

import UIKit

extension Notification.Name {
    static let keyboardWillShow = UIResponder.keyboardWillShowNotification
    static let keyboardWillHide = UIResponder.keyboardWillHideNotification
    static let willEnterForeground = Notification.Name(rawValue: "WillEnterForeground")
}


// Baluchon/Extension/String+appTexts.swift
//
//  String+appTexts.swift
//  Baluchon
//
//  Created by Cristian Rojas on 07/02/2021.
//

import Foundation

enum S {
    
    // MARK: - Generics
    static let french = "french".localized
    static let english = "english".localized
    static let ok = "ok".localized
    static let retry = "retry".localized
    static let attention = "attention".localized
    
    // MARK: - Weather
    static let weather = "weather".localized
    
    // MARK: - Exchange
    static let convert = "convert".localized
    static var formatedRate: (Float) -> (String) = { rate in
        let rateString = String(format: "%.2f", rate) + Symbols.usd.string
        return "1\(Symbols.eur.string) = \(rateString)"
    }
    
    // MARK: - Translation
    static let translate = "translate".localized
    static let translateInputPlaceholder = "translate_input_placeholder".localized
    static let translateOutputPlaceholder = "translate_output_placeholder".localized
    
    // MARK: - Error
    static let errorLocalWeather = "error_local_weather".localized
    static let errorDestinationWeather = "error_destination_weather".localized
    static let errorExchange = "error_exchange".localized
    static let errorTranslation = "error_translation".localized
    static let errorDate = "error_casting_date".localized
}



// Baluchon/Extension/String+localized.swift
//
//  Strings+localize.swift
//  Baluchon
//
//  Created by Cristian Rojas on 07/02/2021.
//

import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}


// Baluchon/Extension/UIColor.swift
//
//  UIColor.swift
//  Baluchon
//
//  Created by Cristian Rojas on 06/02/2021.
//

import UIKit

extension UIColor {
    class var azure: UIColor {
        return UIColor(named: "azure")!
    }
    
    class var greyWhite: UIColor {
        return UIColor(named: "greyWhite")!
    }
    
    class var lightGrey: UIColor {
        return UIColor(named: "lightGrey")!
    }
//    class var white: UIColor {
//        return UIColor(named: "white")!
//    }
}


// Baluchon/Extension/UIImage+getShadow.swift
//
//  UIImage+getShadow.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension UIImage {
    static func getShadow() -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 10)
        
        let color1 = UIColor.black.cgColor.copy(alpha: 0.2)!
        let color2: CGColor = UIColor.white.cgColor.copy(alpha: 0)!
        gradientLayer.colors = [color2, color1]
        
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}


// Baluchon/Extension/UIView+gradients.swift
//
//  UIView+gradients.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension UIView {
   // For insert layer in Foreground
   func addBlackGradientLayerInForeground(frame: CGRect, colors:[UIColor]){
    let gradient = CAGradientLayer()
    gradient.frame = frame
    gradient.colors = colors.map{$0.cgColor}
    self.layer.addSublayer(gradient)
   }
   // For insert layer in background
   func addBlackGradientLayerInBackground(frame: CGRect, colors:[UIColor]){
    let gradient = CAGradientLayer()
    gradient.frame = frame
    gradient.colors = colors.map{$0.cgColor}
    self.layer.insertSublayer(gradient, at: 0)
   }
}



// Baluchon/Extension/UIView+loadViewFromNib.swift
//
//  UIView+loadViewFromNib.swift
//  Baluchon
//
//  Created by Cristian Rojas on 23/01/2021.
//

import Foundation
import UIKit

extension UIView {
    func loadViewFromNib(nibName: String) -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
}

//    private func commonInit() {
//        Bundle.main.loadNibNamed("WeatherItemView", owner: self, options: nil)
//        addSubview(contentView)
//        contentView.frame = self.bounds
//        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
//    }


// Baluchon/Extension/UIViewController+escapeKeyboard.swift
//
//  UIViewController+escapeKeyboard.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension UIViewController {
    func escapeKeyboard() {
        let closeKeyboard = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        
        self.view.addGestureRecognizer(closeKeyboard)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}


// Baluchon/Extension/UIViewController+showAlert.swift
//
//  UIViewController+showAlert.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension UIViewController {
    func showErrorAlert(message: String, retryAction: @escaping () -> ()) {
        let alert = UIAlertController(title: S.attention, message: message, preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(title: S.ok, style: .default)
        
        let retryAction = UIAlertAction(title: S.retry, style: .default) { _ in
            retryAction()
        }
        
        alert.addAction(okAction)
        alert.addAction(retryAction)
        present(alert, animated: true)
    }
}


// Baluchon/Extension/URLSession+decode.swift
//
//  URLSession.swift
//  Baluchon
//
//  Created by cris on 18/12/2020.
//

import Foundation

extension URLSession {
    
    static let shared = URLSession(configuration: .default)
    static func decode<T: Decodable>(url: URL?, into type: T.Type, with completion: @escaping (Result<T, Error>) -> Void) {
        
        guard let safeURL = url else {
            completion(.failure(Error(type: .invalidURL)))
            return
        }
        
        #if DEBUG
        print(safeURL)
        #endif
        
        let task = shared.dataTask(with: safeURL) { (data, response, error) in
            
            guard error == nil else {
                completion(.failure(Error(type: .networkError)))
                return
            }
            
            guard let safeData = data else {
                completion(.failure(Error(type: .noDataError)))
                return
            }
            
            guard let decodedData = safeData.mapResponse(into: type) else {
                completion(.failure(Error(type: .decodingError)))
                return
            }
            
            completion(.success(decodedData))
        }
        task.resume()
    }
}


// Baluchon/Screen/Exchange/ExchangeViewController.swift
//
//  ExchangeViewController.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import UIKit

class ExchangeViewController: UIViewController, ExchangeRepositoryOutput, UITextFieldDelegate {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var rateLabel: UILabel!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var rateContainer: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var rate: Float = 0.0 {
        didSet {
            self.rateLabel.text = S.formatedRate(rate)
        }
    }
    

    lazy var repository: ExchangeRepositoryInput = {
        let repo = ExchangeRepository(api: Api.fixer)
        repo.output = self
        return repo
    }()
    
    enum Operations {
        case multiply
        case divide
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addObservers()
        setupKeyboardHandler()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       removeObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchExchange()
        
        //@todo:
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidBeginEditing(_:)), for: .editingChanged)
    }
    
    private func fetchExchange() {
        guard let exchangeRate = UserDefaults.standard.value(forKey: .exchangeRate) as? Float else {
            repository.fetchExchange()
            return
        }
        rate = exchangeRate
        refetchIfNeeded()
    }
    
    @objc
    private func refetchIfNeeded() {
        
        guard let lastFetchingDate = UserDefaults.standard.value(forKey: .fetchingDate) as? Date else {
            didUpdate(state: .error(S.errorDate))
            return
        }
        
        let currentDate = Date()
        
        if currentDate.moreThanADay(from: lastFetchingDate) {
            UserDefaults.standard.setValue(currentDate, forKey: .fetchingDate)
            repository.fetchExchange()
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: .keyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refetchIfNeeded),
            name: .willEnterForeground, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .keyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .willEnterForeground, object: nil)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let safeFieldText = textField.text else { return }
        if safeFieldText.isEmpty {
            resultLabel.text = "0"
        } else {
        convertCurrency()
        }
    }
}

// MARK: - Setup UI
private extension ExchangeViewController {
    
    func setupUI() {

        activityIndicator.hidesWhenStopped = true
        
        rateContainer.layer.borderColor = UIColor.lightGrey.cgColor
        rateContainer.layer.borderWidth = 3.0
        rateContainer.layer.cornerRadius = rateContainer.frame.height / 2
    }
    
    func setupKeyboardHandler() {
        
        textField.becomeFirstResponder()
        escapeKeyboard()
    }
    
    func convertCurrency() {
        
        guard
            let stringNumber = textField.text,
            let numberToConvert: Float = Float(stringNumber)
        else { return }
        
        guard !stringNumber.isEmpty else {
            self.resultLabel.text = "0"
            return
        }
        
        guard let rate = UserDefaults.standard.value(forKey: .exchangeRate) as? Float  else {
            didUpdate(state: .error("Error casting exchange rate"))
            return
        }
        
        let result = numberToConvert * rate
        self.resultLabel.text = "\(result)"
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = keyboardSize.cgRectValue
        if bottomConstraint.constant == 0 {
            bottomConstraint.constant -= keyboardFrame.height
        }
    }
}


// Baluchon/Screen/Exchange/ExchangeViewController+didFetch.swift
//
//  ExchangeDidFetch.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import Foundation

extension ExchangeViewController {
    func didFetchExchange(result: Result<ExchangeResponse, Error>) {
        switch result {
        case .success(let response):
            didUpdate(state: .success(response))
        case .failure(let error):
            didUpdate(state: .error(error.type.message))
        }
    }
}


// Baluchon/Screen/Exchange/ExchangeViewController+didUpdate.swift
//
//  ExchangeDidUpdate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import Foundation

extension ExchangeViewController {
    
    func didUpdate(state: ExchangeViewState) {
        if state.isLoading {
            activityIndicator.startAnimating()
            self.rateLabel.isHidden = true
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
            }
        }
        
        switch state {
        case .success(let response):
            DispatchQueue.main.async { [weak self] in
                let rate: Float = response.rates.usd
                self?.setUserDefaults(rate: rate)
                self?.formatAndDisplay(rate: rate)
            }
        case .error(let error):
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showErrorAlert(message: S.errorExchange, retryAction: self.repository.fetchExchange)
            }
            #if DEBUG
            print(error)
            #endif
        default: break
        }
    }
}

private extension ExchangeViewController {
    func setUserDefaults(rate: Float) {
        UserDefaults.standard.setValue(rate, forKey: .exchangeRate)
        UserDefaults.standard.setValue(Date(), forKey: .fetchingDate)
    }
    
    func formatAndDisplay(rate: Float) {
        rateLabel.text = S.formatedRate(rate)
        rateLabel.isHidden = false
    }
}


// Baluchon/Screen/Exchange/ExchangeViewState.swift
//
//  ExchangeViewState.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

enum ExchangeViewState: Equatable {
    case loading
    case success(ExchangeResponse)
    case error(String)
    
    var isLoading: Bool {
        self == .loading
    }
}


// Baluchon/Screen/Translation/TranslationViewController.swift
//
//  TranslationViewController.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import UIKit

class TranslationViewController: UIViewController, TranslationRepositoryOutput {
    
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var outputTextView: UITextView!
    @IBOutlet weak var componentContainer: UIView!
    @IBOutlet weak var textToTranslateContainer: UIView!
    @IBOutlet weak var translationContainer: UIView!
    
    @IBOutlet weak var inputLangImage: UIImageView!
    @IBOutlet weak var outputLangImage: UIImageView!
    
//    @IBOutlet weak var inputLangLabel: UILabel!
    @IBOutlet weak var outputLangLabel: UILabel!
    @IBOutlet weak var translationButton: DefaultButton!
    
    lazy var repository: TranslationRepositoryInput = {
        let repo = TranslationRepository(api: Api.googleTranslate)
        repo.output = self
        return repo
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    @IBAction func translationButtonPressed(_ sender: Any) {
        repository.fetchTranslation(query: inputTextView.text)
        inputTextView.resignFirstResponder()
    }
}

// MARK: - Setup UI
private extension TranslationViewController {
    func setupUI() {
        let cornerRadius: CGFloat = 10
        
        inputTextView.text = S.translateInputPlaceholder
        outputTextView.text = S.translateOutputPlaceholder
        
//        inputLangLabel.text = S.french
        outputLangLabel.text = S.english
        
        outputTextView.textColor = UIColor.lightGray
        inputTextView.textColor = UIColor.lightGray
        
        outputTextView.delegate = self
        inputTextView.delegate = self
        
        textToTranslateContainer.layer.cornerRadius = cornerRadius
        textToTranslateContainer.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        
        translationContainer.layer.cornerRadius = cornerRadius
        translationContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        componentContainer.layer.cornerRadius = cornerRadius
        
        componentContainer.layer.shadowColor = UIColor.black.cgColor
        componentContainer.layer.shadowOpacity = 0.1
        componentContainer.layer.shadowOffset = CGSize(width: 1, height: 2)
        componentContainer.layer.shadowRadius = 3
        
        inputLangImage.layer.cornerRadius = inputLangImage.frame.height / 2
        outputLangImage.layer.cornerRadius = outputLangImage.frame.height / 2
        
        escapeKeyboard()
    }
}

// MARK: - TextView Delegate methods
extension TranslationViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = nil
            textView.textColor = .black
        }
    }
}


// Baluchon/Screen/Translation/TranslationViewController+didFetch.swift
//
//  TranslationDidFetch.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension TranslationViewController {
    func didFetchTranslation(result: Result<TranslationResponse, Error>) {
        switch result {
        case .success(let response):
            let translation = response.data.translations[0]
            didUpdate(state: .success(translation))
        case .failure(let error):
            didUpdate(state: .error(error.type.message))
        }
    }
}


// Baluchon/Screen/Translation/TranslationViewController+didUpdate.swift
//
//  TranslationDidUpdate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension TranslationViewController {
    func didUpdate(state: TranslationViewState) {
        DispatchQueue.main.async { [weak self] in
            self?.translationButton.isLoading = state.isLoading
        }
        switch state {
        case .success(let data):
            DispatchQueue.main.async { [weak self] in
                self?.outputTextView.text = data.translatedText
                if let flag = UIImage(named: data.detectedSourceLanguage) {
                    self?.inputLangImage.image = flag
                } else {
                    self?.inputLangImage.image = UIImage(named: "unknown")
                }
            }
        case .error(let error):
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showErrorAlert(message: S.errorTranslation) {
                    self.repository.fetchTranslation(query: self.inputTextView.text)
                }
            }
            #if DEBUG
            print(error)
            #endif
        default: break
        }
    }
}


// Baluchon/Screen/Translation/TranslationViewState.swift
//
//  TranslationViewState.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

enum TranslationViewState: Equatable {
    case loading
    case success(Translation)
    case error(String)
    
    var isLoading: Bool {
        self == .loading
    }
}



// Baluchon/Screen/UI/Component/Button/DefaultButton.swift
//
//  DefaultButton.swift
//  Baluchon
//
//  Created by Cristian Rojas on 06/02/2021.
//

import UIKit

@IBDesignable
class DefaultButton: UIButton {
    
    private let activityIndicator = UIActivityIndicatorView()
    
    var isLoading: Bool = false {
        didSet {
            isEnabled = !isLoading
            handleLoadingState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupButton()
    }
    
    private func setupButton() {
        setTitleColor(.white, for: .normal)
        setTitleColor(.white, for: .highlighted)
        setTitleColor(.white, for: .selected)
        layer.cornerRadius = frame.height / 2
        backgroundColor = .azure
        
        setupIndicator()
    }
    
    private func setupIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .white
        addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            activityIndicator.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func handleLoadingState() {
        if isLoading {
            activityIndicator.startAnimating()
            setTitleColor(.clear, for: .normal)
        } else {
            activityIndicator.stopAnimating()
            setTitleColor(.white, for: .normal)
        }
    }
}


// Baluchon/Screen/UI/ErrorView.swift
//
//  ErrorView.swift
//  Baluchon
//
//  Created by Cristian Rojas on 23/01/2021.
//

import UIKit

class ErrorView: UIView {
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet weak var retryButton: UIButton!
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }


    @IBAction func retryButtonPressed(_ sender: UIButton) {
    }
    
}


// Baluchon/Screen/Weather/Components/WeatherItemView.swift
//
//  WeatherItemView.swift
//  Baluchon
//
//  Created by Cristian Rojas on 23/01/2021.
//

import UIKit

@IBDesignable
final class WeatherItemView: UIView {
    
    @IBOutlet private weak var bgImage: UIImageView!
    @IBOutlet private weak var pictoImage: UIImageView!
    @IBOutlet private weak var cityLabel: UILabel!
    @IBOutlet private weak var tmpLabel: UILabel!
    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private let cornerRadius: CGFloat = 16
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.configureView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.configureView()
    }
    
    func configureView(cityName: String,
                       tmp: String,
                       state: String,
                       image: String,
                       cityImage: String) {
        
            self.setupUI()
            self.cityLabel.text = cityName
            self.tmpLabel.text = "\(tmp) °"
            self.stateLabel.text = state
            self.pictoImage.image = UIImage(named: image)
            self.bgImage.image = UIImage(named: cityImage)
        
    }
    
    func startAnimating() {
        activityIndicator.startAnimating()
        cityLabel.isHidden = true
        tmpLabel.isHidden = true
        stateLabel.isHidden = true
    }
    
    func stopAnimating() {
        activityIndicator.stopAnimating()
        
        cityLabel.isHidden = false
        tmpLabel.isHidden = false
        stateLabel.isHidden = false
        
        guard let first = self.subviews.first else { return }
        first.backgroundColor = .clear
    }
}

private extension WeatherItemView {
    func configureView() {
        guard let view = self.loadViewFromNib(nibName: "WeatherItemView") else { return }
        view.frame = self.bounds
        view.layer.cornerRadius = cornerRadius
        self.addSubview(view)
        activityIndicator.hidesWhenStopped = true
    }
    
    func setupUI() {
        cityLabel.textColor = .white
        tmpLabel.textColor = .white
        stateLabel.textColor = .white
        
        tmpLabel.font = .boldSystemFont(ofSize: 32)
        
        pictoImage.tintColor = .white
        bgImage.addBlackGradientLayerInForeground(frame: self.bounds, colors: [UIColor.clear, UIColor.black])
        bgImage.layer.cornerRadius = 16
    }
}


// Baluchon/Screen/Weather/WeatherViewController.swift
//
//  WeatherViewController.swift
//  Baluchon
//
//  Created by Cristian Rojas on 19/11/2020.
//

import UIKit

class WeatherViewController: UIViewController, WeatherRepositoryOutput {
    
    @IBOutlet weak var weatherTitleLabel: UILabel!
    @IBOutlet weak var destinationView: WeatherItemView!
    @IBOutlet weak var localView: WeatherItemView!
    
    lazy var repository: WeatherRepositoryInput = {
        let repo = WeatherRepository(api: Api.openWeather)
        repo.output = self
        return repo
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        repository.fetchWeather()
    }
    
    private func setupUI() {
        weatherTitleLabel.text = S.weather
        weatherTitleLabel.font = .boldSystemFont(ofSize: 28)
    }
}


// Baluchon/Screen/Weather/WeatherViewController+didFetch.swift
//
//  WeatherDidFetch.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension WeatherViewController {
    func didFetchLocalWeather(result: Result<WeatherResponse, Error>) {
        switch result {
        case .success(let response):
            didUpdateLocal(state: .successLocal(response))
        case .failure(let error):
            didUpdateLocal(state: .errorLocal(error.type.message))
        }
    }
    
    func didFetchDestinationWeather(result: Result<WeatherResponse, Error>) {
        switch result {
        case .success(let response):
            didUpdateDestination(state: .successDestination(response))
        case .failure(let error):
            didUpdateDestination(state: .errorDestination(error.type.message))
        }
    }
}


// Baluchon/Screen/Weather/WeatherViewController+didUpdate.swift
//
//  WeatherDidUpdate.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

import UIKit

extension WeatherViewController {
    
    func didUpdateLocal(state: WeatherViewState) {
        switch state {
        case .loadingLocal:
            localView.startAnimating()
        case .successLocal(let response):
            configureLocalComponent(with: response)
        case .errorLocal(let error):
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showErrorAlert(message: S.errorLocalWeather, retryAction: self.repository.fetchLocalWeather)
            }
            #if DEBUG
            print(error)
            #endif
        default: break
        }
    }
    
    func didUpdateDestination(state: WeatherViewState) {
        switch state {
        case .loadingDestination:
            destinationView.startAnimating()
        case .successDestination(let response):
            configureDestinationComponent(with: response)
        case .errorDestination(let error):
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showErrorAlert(message: S.errorDestinationWeather, retryAction: self.repository.fetchDestinationWeather)
            }
            
            #if DEBUG
            print(error)
            #endif
        default: break
        }
    }
    
    private func configureLocalComponent(with response: WeatherResponse) {
        DispatchQueue.main.async() { [weak self] in
            guard let self = self else { return }
            self.localView.stopAnimating()
            guard let first = response.weather.first else { return }
            self.localView.configureView(cityName: response.name,
                                         tmp: "\(response.main.temp)",
                                         state: first.description.capitalized,
                                         image: first.icon,
                                         cityImage: "chartres")
        }
    }
    
    private func configureDestinationComponent(with response: WeatherResponse) {
        DispatchQueue.main.async() { [weak self] in
            guard let self = self else { return }
            self.destinationView.stopAnimating()
            guard let first = response.weather.first else { return }
            self.destinationView.configureView(
                cityName: response.name,
                tmp: "\(response.main.temp)",
                state: first.description.capitalized,
                image: first.icon,
                cityImage: "new-york"
            )
        }
    }
}


// Baluchon/Screen/Weather/WeatherViewState.swift
//
//  WeatherViewState.swift
//  Baluchon
//
//  Created by Cristian Rojas on 20/02/2021.
//

enum WeatherViewState: Equatable {
    case loadingLocal
    case successLocal(WeatherResponse)
    case errorLocal(String)
    
    case loadingDestination
    case successDestination(WeatherResponse)
    case errorDestination(String)
}


// BaluchonTests/Data/MockWeatherRepository.swift
//
//  MockRepository.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 10/01/2021.
//

@testable import Baluchon

class MockWeatherRepository: WeatherRepositoryInput {
    
    var output: WeatherRepositoryOutput?
    var api: OpenWeatherApiInput?
    
    var withError: Bool
    
    init(withError: Bool = false,
         api: OpenWeatherApiInput?,
         output: WeatherRepositoryOutput?) {
        self.withError = withError
        self.api = api
        self.output = output
    }
    
    func fetchWeather() {}
    
    func fetchDestinationWeather() {
        api?.getDestinationWeather { [weak self] result in
            self?.output?.didFetchDestinationWeather(result: result)
        }
    }
    
    func fetchLocalWeather() {
        api?.getLocalWeather { [weak self] result in
            self?.output?.didFetchLocalWeather(result: result)
        }
    }
}


// BaluchonTests/Data/Registry/RegistryTests.swift
//
//  RegistryTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 20/02/2021.
//

import XCTest
@testable import Baluchon

class RegistryTests: XCTestCase {
    
    override func setUp() {
        Registry.clear()
    }
    
    override func tearDown() {
        Registry.clear()
    }
    
    func testRegistry() {
        XCTAssertNotEqual(Registry.defaults, nil)
        XCTAssertEqual(Registry.defaults.bool(forKey: .fetchingDate), false)
    }
    
    func testBeforeAddingAKey_ValueDoesntExists() {
        if (UserDefaults.standard.value(forKey: .fetchingDate) as? Date) != nil {
            XCTFail()
        } else {
            XCTAssert(true)
        }
    }
    
    func testWhenAddingKey_ValueIsnNilAnymore() {
        let currentDate = Date()
        UserDefaults.standard.setValue(currentDate, forKey: .fetchingDate)
    }
    
    func testValueShouldBeNilOnFirstRun() {
        let currentDate = Date()
        
        if (UserDefaults.standard.value(forKey: .fetchingDate) as? Date) != nil {
            XCTFail()
        } else {
            UserDefaults.standard.setValue(currentDate, forKey: .fetchingDate)
        }
        
        XCTAssertEqual(UserDefaults.standard.value(forKey: .fetchingDate) as! Date, currentDate)
    }
    
    func testComparingSameValues() {
        let currentDate = Date()
        UserDefaults.standard.setValue(currentDate, forKey: .fetchingDate)
        
        let userDefaultsDate = UserDefaults.standard.value(forKey: .fetchingDate) as! Date
        
        let interval = userDefaultsDate.timeIntervalSince(currentDate)
        
        if interval == 0.0 {
            XCTAssert(true)
        } else {
            XCTFail()
        }
    }
    
    func testComparingDifferentValues() {
        var dateComponents = DateComponents()
        dateComponents.year = 1982
        dateComponents.month = 7
        dateComponents.day = 21
        
        let calendar = Calendar(identifier: .gregorian)
        
        /// FirstDate
        let firstDate = calendar.date(from: dateComponents)
        
        /// SecondDate
        dateComponents.day = 20
        let secondDate = calendar.date(from: dateComponents)
        
        UserDefaults.standard.setValue(firstDate, forKey: .fetchingDate)
        
        let userDefaultsDate = UserDefaults.standard.value(forKey: .fetchingDate) as! Date
        
        let interval = userDefaultsDate.timeIntervalSince(secondDate!)
        
        let minute: TimeInterval = 60.0
        let hour: TimeInterval = 60.0 * minute
        let day: TimeInterval = 24 * hour
        
        if interval == day {
            XCTAssert(true)
        } else {
            XCTFail()
        }
    }
    
    func testComparingGreatherThanADay() {
        var dateComponents = DateComponents()
        dateComponents.year = 1982
        dateComponents.month = 7
        dateComponents.day = 21
        
        let calendar = Calendar(identifier: .gregorian)
        
        /// FirstDate
        let firstDate = calendar.date(from: dateComponents)
        
        /// SecondDate
        dateComponents.day = 20
        let secondDate = calendar.date(from: dateComponents)
        
        UserDefaults.standard.setValue(firstDate, forKey: .fetchingDate)
        
        let userDefaultsDate = UserDefaults.standard.value(forKey: .fetchingDate) as! Date
        
        let interval = userDefaultsDate.timeIntervalSince(secondDate!)
        
        let minute: TimeInterval = 60.0
        let hour: TimeInterval = 60.0 * minute
        let day: TimeInterval = 24 * hour
        
        if interval == day {
            XCTAssert(true)
        } else {
            XCTFail()
        }
    }
    
    func testIsFirstTimeFetching() {
        if (UserDefaults.standard.value(forKey: .fetchingDate) as? Date) != nil {
            XCTFail()
        } else {
            XCTAssert(true)
        }
    }
    
    func testUpdatingValue() {
        let date1 = Date()
        UserDefaults.standard.setValue(date1, forKey: .fetchingDate)
        
        let date2 = Date()
        UserDefaults.standard.setValue(date2, forKey: .fetchingDate)
        
        XCTAssertEqual(UserDefaults.standard.value(forKey: .fetchingDate) as! Date, date2)
        
    }
}


// BaluchonTests/Data/Repository/Exchange/FixerRepositoryTests.swift
//
//  FixerRepositoryTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//

import XCTest
@testable import Baluchon

class FixerRepositoryTest: XCTestCase {
    
    var sut: ExchangeRepositoryInput!
    var output: MockFixerRepositoryOutput!
    var api: MockFixerApi!
    
    let expectedResponse = ExchangeResponse(rates: Rates(usd: 20.5))
    
    override func setUp() {
        output = MockFixerRepositoryOutput()
        api = MockFixerApi()
        sut = ExchangeRepository(api: api)
        sut.output = output
        
        api.response = expectedResponse
    }
    
    override func tearDown() {}
    
    func testFetchExchangeWithSuccess() {
        sut.fetchExchange()
        if case .success = output.model {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchExchangeWithError() {
        api.withError = true
        sut.fetchExchange()
        if case .failure = output.model {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchingChangesStateSuccess() {
        sut.fetchExchange()
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .success(expectedResponse))
    }
    
    func testFetchingChangesStateFailureCase() {
        api.withError = true
        sut.fetchExchange()
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .error("error"))
    }
}


// BaluchonTests/Data/Repository/Exchange/MockFixerApi.swift
//
//  MockFixerApi.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//

@testable import Baluchon

class MockFixerApi: FixerApiInput {
    
    var response: ExchangeResponse!
    var withError: Bool
    
    init(withError: Bool = false) {
        self.withError = withError
    }

    func getRate(completion: @escaping ((Result<ExchangeResponse, Error>) -> Void)) {
        if withError {
            completion(.failure(Error(type:.noDataError)))
        } else {
            completion(.success(response))
        }
    }
}


// BaluchonTests/Data/Repository/Exchange/MockFixerRepositoryOutput.swift
//
//  MockFixerRepositoryOutput.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//
@testable import Baluchon

class MockFixerRepositoryOutput: ExchangeRepositoryOutput {
    var model: Result<ExchangeResponse, Error>?
    var states: [ExchangeViewState] = [ ]
    func didFetchExchange(result: Result<ExchangeResponse, Error>) {
        model = result
        switch result {
        case .success(let response):
            states.append(.success(response))
        case .failure:
            states.append(.error("error"))
        }
    }
    
    func didUpdate(state: ExchangeViewState) {
        states.append(state)
    }
}


// BaluchonTests/Data/Repository/Translation/MockTranslateApi.swift
//
//  MockTranslateApi.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//

@testable import Baluchon

class MockTranslateApi: GoogleTranslateApiInput {

    var response: TranslationResponse!
    var withError: Bool
    init(withError: Bool = false) {
        self.withError = withError
    }
    
    func getTranslation(query: String, completion: @escaping ((Result<TranslationResponse, Error>) -> Void)) {
        if withError {
            completion(.failure(Error(type: .noDataError)))
        }  else {
            completion(.success(response))
        }
    }
}


// BaluchonTests/Data/Repository/Translation/MockTranslateRepositoryOutput.swift
//
//  MockTranslateRepositoryOutput.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//

@testable import Baluchon

class MockTranslateRepositoryOutput: TranslationRepositoryOutput {
    
    var model: Result<TranslationResponse, Error>?
    var states: [TranslationViewState] = []
    
    func didFetchTranslation(result: Result<TranslationResponse, Error>) {
            model = result
        switch result {
        case .success:
            states.append(.success(Translation(translatedText: "", detectedSourceLanguage: "")))
        case .failure:
            states.append(.error("error"))
        }
    }
    
    /// @toDo
    func didUpdate(state: TranslationViewState) {
        states.append(state)
    }
}


// BaluchonTests/Data/Repository/Translation/TranslateRepositoryTests.swift
//
//  TranslateRepositoryTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 17/01/2021.
//

import XCTest
@testable import Baluchon

class TranslateRepositoryTests: XCTestCase {
    
    var sut: TranslationRepositoryInput!
    var output: MockTranslateRepositoryOutput!
    var api: MockTranslateApi!
    
    var expectedApiResponse = TranslationResponse(data: TranslationData(translations: []))
    
    override func setUp() {
        output = MockTranslateRepositoryOutput()
        api = MockTranslateApi()
        sut = TranslationRepository(api: api)
        sut.output = output
        
        api.response = expectedApiResponse
    }
    
    func testFetchTranslationWithSuccess() {
        sut.fetchTranslation(query: "tests")
        if case .success = output.model {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchTranslationWithError() {
        api.withError = true
        sut.fetchTranslation(query: "tests")
        if case .failure = output.model {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchingChangesStateSuccess() {
        sut.fetchTranslation(query: "test")
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .success(Translation(translatedText: "", detectedSourceLanguage: "")))
    }
    
    func testFetchingChangesStatFailure() {
        api.withError = true
        sut.fetchTranslation(query: "test")
        XCTAssertEqual(output.states.count, 2)
        XCTAssertEqual(output.states.last, .error("error"))
    }
}


// BaluchonTests/Data/Repository/Weather/MockWeatherApi.swift
//
//  MockWeatherApi.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 14/01/2021.
//

import Foundation
@testable import Baluchon

class MockWeatherApi: OpenWeatherApiInput {
    
    var localResponse: WeatherResponse!
    var destinationResponse: WeatherResponse!
    
    var withError: Bool
    
    init(withError: Bool = false) {
        self.withError = withError
    }
    
    func getLocalWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void) {
        if withError {
            completion(.failure(Error(type: .noDataError)))
        } else {
            completion(.success(localResponse))
        }
    }
    
    func getDestinationWeather(completion: @escaping (Result<WeatherResponse, Error>) -> Void) {
        
        if withError {
            completion(.failure(Error(type: .noDataError)))
        } else {
            completion(.success(destinationResponse))
        }
    }
    
}


// BaluchonTests/Data/Repository/Weather/MockWeatherRepositoryOutput.swift
//
//  MockWeatherRepositoryOutput.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 14/01/2021.
//

import Foundation
@testable import Baluchon

class MockWeatherRepositoryOutput: WeatherRepositoryOutput {
    
    var localStates: [WeatherViewState] = [ ]
    var destinationStates: [WeatherViewState] = [ ]
    var local: Result<WeatherResponse, Error>?
    var destination: Result<WeatherResponse, Error>?
    
    func didFetchLocalWeather(result: Result<WeatherResponse, Error>) {
        local = result
        switch result {
        case .success(let success):
            localStates.append(.successLocal(success))
        case .failure:
            localStates.append(.errorLocal("error"))
        }
    }
    
    func didFetchDestinationWeather(result: Result<WeatherResponse, Error>) {
        destination = result
        switch result {
        case .success(let success):
            destinationStates.append(.successDestination(success))
        case .failure:
            destinationStates.append(.errorDestination("error"))
        }
    }
    
    func didUpdateDestination(state: WeatherViewState) {
       destinationStates.append(state)
    }
    
    func didUpdateLocal(state: WeatherViewState) {
        localStates.append(state)
    }
}


// BaluchonTests/Data/Repository/Weather/OpenWeatherRepositoryTests.swift
//
//  WeatherResponseTest.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 10/01/2021.
//

import XCTest
@testable import Baluchon

class OpenWeatherRepositoryTests: XCTestCase {
    
    var output: MockWeatherRepositoryOutput!
    var api: MockWeatherApi!
    var sut: WeatherRepository!
    
    
    static var expectedLocalResponse = WeatherResponse(name: "Chartres", main: WeatherTemp(temp: 20), weather: [])
    static var expectedDestinationResponse = WeatherResponse(name: "NewYork", main: WeatherTemp(temp: 20), weather: [])
    
    override func setUp() {
        
        output = MockWeatherRepositoryOutput()
        api = MockWeatherApi()
        
        api.localResponse = OpenWeatherRepositoryTests.expectedLocalResponse
        api.destinationResponse = OpenWeatherRepositoryTests.expectedDestinationResponse
        
        sut = WeatherRepository(api: api)
        sut.output = output
        
    }
    
    override func tearDown() {
        api = nil
        output = nil
        sut = nil
    }
    
    func testFetchLocalWeatherWithSuccess() {
        
        sut.fetchLocalWeather()
        if case .success = output.local {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchLocalWeatherWithError() {
        api.withError = true
        sut.fetchLocalWeather()
        if case .failure = output.local {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchDestinatioinWeatherWithSuccess() {
        sut.fetchDestinationWeather()
        if case .success = output.destination {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchDestinationlWeatherWithError() {
        api.withError = true
        sut.fetchDestinationWeather()
        if case .failure = output.destination {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testFetchingLocalChangesStateSuccess() {
        sut.fetchLocalWeather()
        XCTAssertEqual(output.localStates.count, 2)
        XCTAssertEqual(output.localStates.last, .successLocal(OpenWeatherRepositoryTests.expectedLocalResponse))
        
       
    }
    
    func testFetchingLocalnChangesStateFailure() {
        /// With error
        api.withError = true
        sut.fetchLocalWeather()
        XCTAssertEqual(output.localStates.count, 2)
        XCTAssertEqual(output.localStates.last, .errorLocal("error"))
    }
    
    func testFetchingDestinationChangesStateSuccess() {
        sut.fetchDestinationWeather()
        XCTAssertEqual(output.destinationStates.count, 2)
        XCTAssertEqual(output.destinationStates.last, .successDestination(OpenWeatherRepositoryTests.expectedDestinationResponse))
    }
    
    func testFetchingDestinationChangesStateFailure() {
        api.withError = true
        sut.fetchDestinationWeather()
        XCTAssertEqual(output.destinationStates.count, 2)
        XCTAssertEqual(output.destinationStates.last, .errorDestination("error"))
    }
}


// BaluchonTests/Data/Services/ReponseMappingTests.swift
//
//  ReponseMappingTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 20/02/2021.
//

import XCTest
@testable import Baluchon

class ReponseMappingTests: XCTestCase {
    
    func testMapResponse() {
        guard let weather = decodeJsonFile(filename: "WeatherResponse", decodable: true) else { return }
     
        XCTAssertEqual(weather.name, "Chartres")
    }
    
    func testMapResponseWithError() {
        let weather = decodeJsonFile(filename: "UndecodableResponse", decodable: false)
        XCTAssertEqual(weather, nil)
    }
    
    private func decodeJsonFile(filename: String, decodable: Bool) -> WeatherResponse? {
        let bundle = Bundle(for: type(of: self))
        
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            XCTFail("Missing file: \(filename).json")
            return nil
        }
        
        let json = try? Data(contentsOf: url)
        
        guard let weather = json?.mapResponse(into: WeatherResponse.self) else { return nil }
        return weather
    }
}


// BaluchonTests/Extensions/Date+intervalChecker.swift
//
//  Date+intervalChecker.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 07/03/2021.
//

import XCTest
@testable import Baluchon

class DateTests: XCTestCase {
    
    func testIntervalShouldBeGreather() {
        var dateComponents = DateComponents()
        
        dateComponents.year = 2021
        dateComponents.month = 3
        dateComponents.day = 7
        
        let calendar = Calendar(identifier: .gregorian)
        
        let firstDate = calendar.date(from: dateComponents)
        
        /// Create seconde date: two days after first date
        dateComponents.day = 9
        let secondDate = calendar.date(from: dateComponents)
        
        if secondDate!.moreThanADay(from: firstDate!) {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testIntervalShouldBeZero() {
        var dateComponents = DateComponents()
        
        dateComponents.year = 2021
        dateComponents.month = 3
        dateComponents.day = 7
        
        let calendar = Calendar(identifier: .gregorian)
        
        let firstDate = calendar.date(from: dateComponents)
        
        dateComponents.day = 7
        let secondDate = calendar.date(from: dateComponents)
        
        let interval = secondDate!.timeIntervalSince(firstDate!)
        if interval == 0 {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    func testIntervalShouldBe_3600() {
        var dateComponents = DateComponents()
        
        dateComponents.year = 2021
        dateComponents.month = 3
        dateComponents.day = 7
        dateComponents.hour = 14
        
        let calendar = Calendar(identifier: .gregorian)
        
        let firstDate = calendar.date(from: dateComponents)
        
        /// Create seconde date: firstDate + 1 hour
        dateComponents.hour! += 1
        let secondDate = calendar.date(from: dateComponents)
        
        let interval = secondDate!.timeIntervalSince(firstDate!)
        
        /// 3600s = 1 hour
        if interval == 3600 {
            XCTAssert(true)
        } else {
            XCTAssert(false)
        }
    }
    
    
    func testIntervalShouldBeLesser() {
        var dateComponents = DateComponents()
        
        dateComponents.year = 2021
        dateComponents.month = 3
        dateComponents.day = 7
        dateComponents.hour = 15
        
        let calendar = Calendar(identifier: .gregorian)
        
        let firstDate = calendar.date(from: dateComponents)
        
        dateComponents.day = 7
        dateComponents.hour = 16
        let secondDate = calendar.date(from: dateComponents)
        
        if secondDate!.moreThanADay(from: firstDate!) {
            XCTAssert(false)
        } else {
            XCTAssert(true)
        }
    }
}


// BaluchonTests/Extensions/UIColorTests.swift
//
//  UIColorTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 06/02/2021.
//

import UIKit
import XCTest
@testable import Baluchon

class UIColorTests: XCTestCase {
    
    func testColorArenFound() {
        XCTAssertNotEqual(UIColor.azure, nil)
        XCTAssertNotEqual(UIColor.greyWhite, nil)
        XCTAssertNotEqual(UIColor.lightGrey, nil)
//        XCTAssertNotEqual(UIColor.white, nil)

    }
}


// BaluchonTests/Model/SymbolsTests.swift
//
//  SymbolsTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 20/02/2021.
//

import XCTest
@testable import Baluchon

class SymbolsTests: XCTestCase {

    func testSymbols() {
        XCTAssertEqual(Symbols.eur.string,"€")
        XCTAssertEqual(Symbols.usd.string, "$")
    }

}


// BaluchonTests/Screens/Weather/WeatherVCTests.swift
//
//  WeatherVCTests.swift
//  BaluchonTests
//
//  Created by Cristian Rojas on 10/01/2021.
//

import XCTest
@testable import Baluchon


@available(iOS 13.0, *)
class WeatherVCTests: XCTestCase {
    
    var sut: WeatherViewController!
    var repository: WeatherRepositoryInput!
    
    override func setUp() {
        repository = WeatherRepository(api: MockWeatherApi())
        sut = WeatherViewController()
//        sut.repository = repository
    }
    
    override func tearDown() {
        repository = nil
        sut = nil
    }
    
    
    func testGivenIdleState_WhenLoadModel_ThenStateGoesFromIdleSuccess() {
        _ = [
            WeatherViewState.loadingDestination,
            WeatherViewState.successDestination(WeatherResponse(name: "", main: WeatherTemp(temp: 0.0), weather: []))
        ]
    }
    
}





// BaluchonUITests/BaluchonUITests.swift
//
//  BaluchonUITests.swift
//  BaluchonUITests
//
//  Created by Cristian Rojas on 19/11/2020.
//

import XCTest

class BaluchonUITests: XCTestCase {
}



// p6-count-on-me.swift

// CountONMe.playground/Contents.swift
import Foundation

enum Operands {
    case plus
    case less
    case multiply
    case divide
    case equal
    
    var symbol: String {
        switch self {
        case .plus:
            return "+"
        case .less:
            return "-"
        case .multiply:
            return "x"
        case .divide:
            return "÷"
        case .equal:
            return "="
        }
    }
}

var operationsToReduce = ["1", Operands.plus.symbol, "2", Operands.multiply.symbol, "2", "+", "2", Operands.divide.symbol, "2"]
/*
 
 ["1", "+", "2", "*", "2", "+", "2", "÷", "2"]
 ["1", "+", "4", "+", "2", "÷", "2"]
 ["1", "+", "4", "+", "1"]
 ["5", "+", "1"]
 ["6"]
 
 */

operationsToReduce.firstIndex { operand -> Bool in
    operand == Operands.multiply.symbol || operand == Operands.divide.symbol
}

/// Iterate over operations while an operand still here

while operationsToReduce.count > 1 {
    
    var result: Float
    
    let firstIndex = operationsToReduce.firstIndex { operand -> Bool in
        operand == Operands.multiply.symbol || operand == Operands.divide.symbol
    }
    
    if let index = firstIndex {
        
        let left = Float(operationsToReduce[index - 1]) ?? 1
        let operand = operationsToReduce[index]
        let right = Float(operationsToReduce[index + 1]) ?? 1
        
        switch operand {
        case Operands.multiply.symbol:
            result = left * right
        case Operands.divide.symbol:
            result = left / right
        default:
            result = 0
        }
        
        let array = [index + 1, index, index - 1]
        for i in array {
            operationsToReduce.remove(at: i)
        }
        
        operationsToReduce.insert("\(result)", at: index-1)
    } else {
        let left = Float(operationsToReduce[0]) ?? 0
        let operand = operationsToReduce[1]
        let right = Float(operationsToReduce[2]) ?? 0
        
        switch operand {
        case Operands.plus.symbol:
            result = left + right
        case Operands.less.symbol:
            result = left - right
        default:
            result = 0
        }
        
        operationsToReduce = Array(operationsToReduce.dropFirst(3))
        operationsToReduce.insert("\(result)", at: 0)
        
    }
    
}

print(operationsToReduce)


// CountOnMe/App/AppDelegate.swift
//
//  AppDelegate.swift
//  SimpleCalc
//
//  Created by Vincent Saluzzo on 29/03/2019.
//  Copyright © 2019 Vincent Saluzzo. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}



// CountOnMe/Controller/CalcViewController.swift
//
//  ViewController.swift
//  SimpleCalc
//
//  Created by Vincent Saluzzo on 29/03/2019.
//  Copyright © 2019 Vincent Saluzzo. All rights reserved.
//

import UIKit

class CalcViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet var numberButtons: [UIButton]!
    
    let calculator = Calculator()
    
    override func viewDidLoad() { super.viewDidLoad() }
    
    // View actions
    @IBAction func tappedResetButton(_ sender: UIButton) {
        textView.text = calculator.reset()
    }
    
    @IBAction func tappedNumberButton(_ sender: UIButton) {
        tapNumber(sender: sender)
    }
    
    @IBAction func tappedAdditionButton(_ sender: UIButton) {
        executeCalc(with: Operands.addition)
    }
    
    @IBAction func tappedSubstractionButton(_ sender: UIButton) {
        executeCalc(with: Operands.substraction)
    }
    
    @IBAction func tappedMultiplicationButton(_ sender: UIButton) {
        executeCalc(with: Operands.multiplication)
    }
    
    @IBAction func tappedDivisionButton(_ sender: UIButton) {
        executeCalc(with: Operands.division)
    }
    
    @IBAction func tappedEqualButton(_ sender: UIButton) {
        tapEqual()
    }
    
}

private extension CalcViewController {
   
    var elements: [String] {
        return textView.text.split(separator: " ").map { "\($0)" }
    }
    
    var expressionHaveResult: Bool {
        return textView.text.firstIndex(of: "=") != nil
    }
    
    
    func tapNumber(sender: UIButton) {
        /// Retrieves number
        guard let numberText = sender.title(for: .normal) else {
            return
        }
        
        /// Clears the textView if its content have a result (tappedEqualButton) or has been cleaned with the "AC" button (textView.text == 0)
        if textView.text == "0" || expressionHaveResult {
            textView.text = ""
        }
        
        textView.text.append(numberText)
    }
    
    func tapEqual() {
        if expressionHaveResult {
            textView.text = calculator.reset()
        } else {
            let result = calculator.compute(elements: elements)
            
            switch result {
            case .failure(let error):
                presentErrorAlert(with: error.title, and: error.message)
            case .success(let success):
                textView.text.append(" = \(success)")
            }
        }
    }
    
    func executeCalc(with operand: Operands) {
        if calculator.expressionIsCorrect(elements: elements) {
            textView.text.append(" \(operand.symbol) ")
        } else {
            presentErrorAlert(with: CalcError.moreThanOneOperator.title, and: CalcError.moreThanOneOperator.message)
        }
    }
}

extension CalcViewController: UITextViewDelegate {
    
}



// CountOnMe/Extensions/Double+Format.swift
//
//  Float+isInt.swift
//  CountOnMe
//
//  Created by Cristian Rojas on 30/10/2020.
//  Copyright © 2020 Vincent Saluzzo. All rights reserved.
//

import Foundation

extension Double {
    var format: String {
        let intMax = Double(Int.max)
        if self.truncatingRemainder(dividingBy: 1) == 0 && self < intMax {
            return "\(Int(self))"
        } else {
            return "\(self)"
        }
    }
}


// CountOnMe/Extensions/UIViewController+PresentAlert.swift
//
//  UIViewController+PresentAlert.swift
//  CountOnMe
//
//  Created by Cristian Rojas on 16/10/2020.
//  Copyright © 2020 Vincent Saluzzo. All rights reserved.
//

import UIKit

extension UIViewController {
    func presentErrorAlert(with title: String, and message: String) {
        // passer autre button
        // extension uiviewcontroller
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alertVC, animated: true, completion: nil)
    }
}


// CountOnMe/Model/CalcError.swift
//
//  Constants.swift
//  CountOnMe
//
//  Created by Cristian Rojas on 16/10/2020.
//  Copyright © 2020 Vincent Saluzzo. All rights reserved.
//

enum CalcError: Error {
    
    case incorrectExpression
    case notEnoughElements
    case moreThanOneOperator
    case inconvertibleString
    
    
    var title: String {
        switch self {
        case .incorrectExpression:
            return "Expression incorrecte"
        case .notEnoughElements:
            return "L'expression n'a pas assez d'éléments"
        case .moreThanOneOperator:
            return "Ce n'est pas possible d'ajouter un nouveau operateur"
        case .inconvertibleString:
            return "Impossible de convetir"
        }
    }
    
    var message: String {
        switch self {
        case .incorrectExpression:
            return "Entrez une expression correcte!"
        case .notEnoughElements:
            return "Démarrez un nouveau calcul!"
        case .moreThanOneOperator:
            return "Un operateur est déja mis!"
        case .inconvertibleString:
            return "Il n'est pas possible de convertir le string en float"
        }
    }
}



// CountOnMe/Model/Calculator.swift
//
//  Calculator.swift
//  CountOnMe
//
//  Created by Cristian Rojas on 16/10/2020.
//  Copyright © 2020 Vincent Saluzzo. All rights reserved.
//

class Calculator {
    
    func expressionIsCorrect(elements: [String]) -> Bool {
        return elements.last != Operands.addition.symbol
            && elements.last != Operands.substraction.symbol
            && elements.last != Operands.multiplication.symbol
            && elements.last != Operands.division.symbol
    }
    
    func reset() -> String {
        return "0"
    }
    
    func compute(elements: [String]) -> Result<String, CalcError> {
        guard expressionIsCorrect(elements: elements) else {
            return .failure(CalcError.incorrectExpression)
        }
        
        guard expressionHaveEnoughElement(elements: elements) else {
            return .failure(CalcError.notEnoughElements)
        }
        
        var operationsToReduce = elements
        
        while operationsToReduce.count > 1 {
            var result: Double = 0.0
            
            let firstIndex = operationsToReduce.firstIndex { operand -> Bool in
                operand == Operands.multiplication.symbol || operand == Operands.division.symbol
            }
            
            if let index = firstIndex {
                do {
                    try computePrioritaryOperations(operationsToReduce: &operationsToReduce, index: index, result: &result)
                } catch {
                    if let error = error as? CalcError { return .failure(error) }
                }
                
            } else {
                do {
                    try computeNonPrioritaryOperations(operationsToReduce: &operationsToReduce, result: &result)
                } catch {
                    if let error = error as? CalcError { return .failure(error) }
                }
            }
        }
        
        return .success(operationsToReduce.first ?? "")
    }
}


// MARK: - Private methods
private extension Calculator {
    
    func expressionHaveEnoughElement(elements: [String]) -> Bool {
        return elements.count >= 3
    }
    
    func computePrioritaryOperations(operationsToReduce: inout [String], index: Int, result: inout Double) throws {
        guard let left = Double(operationsToReduce[index - 1]) else { throw CalcError.inconvertibleString }
        let operand = operationsToReduce[index]
        guard let right = Double(operationsToReduce[index + 1]) else { throw CalcError.inconvertibleString }
       
        if operand == Operands.multiplication.symbol {
            result = left * right
        } else if operand == Operands.division.symbol {
            result = left / right
        }
        
        let array = [index + 1, index, index - 1]
        for i in array {
            operationsToReduce.remove(at: i)
        }
        
        operationsToReduce.insert(result.format, at: index - 1)
    }
    
    func computeNonPrioritaryOperations(operationsToReduce: inout [String], result: inout Double) throws {
        guard let left = Double(operationsToReduce[0]) else { throw CalcError.inconvertibleString }
        let operand = operationsToReduce[1]
        guard let right = Double(operationsToReduce[2]) else { throw CalcError.inconvertibleString }
        
        if operand == Operands.addition.symbol {
            result = left + right
        } else if operand == Operands.substraction.symbol {
            result = left - right
        }
        
        operationsToReduce = Array(operationsToReduce.dropFirst(3))
        operationsToReduce.insert(result.format, at: 0)
    }
}
   


// CountOnMe/Model/Operands.swift
//
//  Operands.swift
//  CountOnMe
//
//  Created by Cristian Rojas on 16/10/2020.
//  Copyright © 2020 Vincent Saluzzo. All rights reserved.
//

enum Operands {
    case addition
    case substraction
    case multiplication
    case division

    
    var symbol: String {
        switch self {
        case .addition:
            return "+"
        case .substraction:
            return "-"
        case .multiplication:
            return "x"
        case .division:
            return "÷"
        }
    }
}


// SimpleCalcTests/SimpleCalcTests.swift
//
//  SimpleCalcTests.swift
//  SimpleCalcTests
//
//  Created by Vincent Saluzzo on 29/03/2019.
//  Copyright © 2019 Vincent Saluzzo. All rights reserved.
//

import XCTest
@testable import CountOnMe

class SimpleCalcTests: XCTestCase {
    
    var calculator: Calculator!
    
    override func setUp() {
        calculator = Calculator()
    }
    
    func testGivenLastCharacterIsntAnOperator_WhenCallingExpressionIsCorrect_ThenWeShouldGetTrue() {
        
        XCTAssertFalse(calculator.expressionIsCorrect(elements: ["+"]))
        XCTAssertTrue(calculator.expressionIsCorrect(elements: ["1"]))
    }
    
    func testResetButton() {
        let reset = calculator.reset()
        XCTAssertEqual(reset, "0")
    }
    
    // MARK: - Addition & subscraction
    
    func testGiven1plus1_WhenCallingCompute_ThenWeShouldGet2() {
        let operation = calculator.compute(elements: ["1", Operands.addition.symbol, "1"])
        XCTAssertEqual(operation, .success("2"))
    }
    
    func testGiven2minus1_WhenCallingCompute_ThenWeShouldGet1() {
        let operation = calculator.compute(elements: ["2", Operands.substraction.symbol, "1"])
        XCTAssertEqual(operation, .success("1"))
    }
    
    // MARK: - Multiplcation & Division
    
    func testGiven2times2_WhenCallingCompute_ThenWeShouldGet4() {
        let operation = calculator.compute(elements: ["2", Operands.multiplication.symbol, "2"])
        XCTAssertEqual(operation, .success("4"))
    }
    
    func testGiven10divided5_WhenCallingCompute_ThenWeShouldGet2() {
        let operation = calculator.compute(elements: ["10", Operands.division.symbol, "5"])
        XCTAssertEqual(operation, .success("2"))
    }
    
    func testGiven5divided2_WhenCallingCompute_ThenWeShouldGet2dot5() {
        let operation = calculator.compute(elements: ["5", Operands.division.symbol, "2"])
        XCTAssertEqual(operation, .success("2.5"))
    }

    func testGivenNumberIsDividedByZero_WhenCallingCompute_ThenWeShouldGetInfinite() {
        let operation = calculator.compute(elements: ["1", Operands.division.symbol, "0"])
        XCTAssertEqual(operation, .success("inf"))
    }
    
    func testGivenZeroIsDividedByNumber_WhenCallingCompute_ThenWeShouldGetZero() {
        let operation = calculator.compute(elements: ["0", Operands.division.symbol, "2"])
        XCTAssertEqual(operation, .success("0"))
    }
    
    func testGivenZeroIsMultipliedByNumber_WhenCallingCompute_ThenWeShouldGetZero() {
        let operation = calculator.compute(elements: ["0", Operands.multiplication.symbol, "2"])
        XCTAssertEqual(operation, .success("0"))
    }
    
    func testGivenZeroIsDividedByZero_WhenCallingCompute_ThenWeShouldGetNotANumber() {
        let operation = calculator.compute(elements: ["0", Operands.division.symbol, "0"])
        XCTAssertEqual(operation, .success("-nan"))
    }
    
    // MARK: - Prioritary order
    func testGiven1plus1times2_WhenCallingCompute_ThenWeShouldGetThree() {
        let operation = calculator.compute(elements: ["1", Operands.addition.symbol, "1", Operands.multiplication.symbol, "2"])
        XCTAssertEqual(operation, .success("3"))
    }
    
    // MARK: - Multiplication with Big numbers
    func testGiven1e48Times1e48_WhenCallingCompute_ThenWeShouldGet1e96() {
        let double: Double = pow(10, 48)
        let bigNumber = "\(double)"
        let operation = calculator.compute(elements: [bigNumber, Operands.multiplication.symbol, bigNumber])
        XCTAssertEqual(operation, .success("1e+96"))
    }
    
    // MARK: - Errors
    func testGivenExpressionIsIncorrect_WhenCallingCompute_ThenWeShouldGetAFailure() {
        let operation = calculator.compute(elements: ["1", "+"])
        switch operation {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertEqual(error, CalcError.incorrectExpression)
            XCTAssertEqual(error.title, "Expression incorrecte")
            XCTAssertEqual(error.message, "Entrez une expression correcte!")
        }
    }
    
    func testGivenExpressionHasntEnoughElements_WhenCallingCompute_ThenWeShouldGetAFailure() {
        
        let operation = calculator.compute(elements: ["1"])
        XCTAssertEqual(operation, .failure(CalcError.notEnoughElements))
        
        switch operation {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertEqual(error, CalcError.notEnoughElements)
            XCTAssertEqual(error.title, "L'expression n'a pas assez d'éléments")
            XCTAssertEqual(error.message, "Démarrez un nouveau calcul!")
        }
    }
    
    func testGivenElementIsInconvertible_WhenCallingComputeWithPriority_ThenShouldGetCalcErrorInconvertibleString() {
        var operation = calculator.compute(elements: ["a", Operands.multiplication.symbol, "2"])
        switch operation {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertEqual(error.title, "Impossible de convetir")
            XCTAssertEqual(error.message, "Il n'est pas possible de convertir le string en float")
        }
        
        operation = calculator.compute(elements: ["1", Operands.multiplication.symbol, "a"])
        XCTAssertEqual(operation, .failure(CalcError.inconvertibleString))
    }
    
    func testGivenElementIsInconvertible_WhenCallingComputeWithoutPriority_ThenWeShouldGetCalcErrorInconvertibleString() {
        var operation = calculator.compute(elements: ["a", Operands.addition.symbol, "1"])
        XCTAssertEqual(operation, .failure(CalcError.inconvertibleString))
        operation = calculator.compute(elements: ["1", Operands.addition.symbol, "a"])
        XCTAssertEqual(operation, .failure(CalcError.inconvertibleString))
    }
    
    // MARK: - Errors not used on calculator class
    func testMoreThanOneOperator() {
        let error = CalcError.moreThanOneOperator
        XCTAssertEqual(error.title, "Ce n'est pas possible d'ajouter un nouveau operateur")
        XCTAssertEqual(error.message, "Un operateur est déja mis!")
    }

}




