# Angular Standards Guide
*Enterprise-Grade Development Standards for Angular Applications*

**Version:** 1.0.0  
**Last Updated:** April 22nd, 2026  
**Status:** Ratified

----

## Table of Contents

1. [Code Structure & Design](#1-code-structure--design)
2. [Architectural Patterns](#2-architectural-patterns)
3. [Security Standards](#3-security-standards)
4. [Performance and Resiliency](#4-performance-and-resiliency)
5. [Monitoring & Logging](#5-monitoring--logging)
6. [Testing Standards](#6-testing-standards)
7. [Code Quality & Maintenance](#7-code-quality--maintenance)

---

## 1. Code Structure & Design

### 1.1 Layered Architecture

#### Standard Project Structure

```
src/
├── app/
│   ├── core/                    # Singleton services, guards, interceptors
│   │   ├── guards/              # Route guards (AuthGuard, RoleGuard)
│   │   ├── interceptors/        # HTTP interceptors (Auth, Error, Logging)
│   │   ├── services/            # Application-wide singleton services
│   │   ├── models/              # Global interfaces, enums, types
│   │   ├── constants/           # Application constants and configurations
│   │   ├── utils/               # Pure utility functions
│   │   └── core.module.ts       # Core module (imported once in AppModule)
│   ├── shared/                  # Reusable components, directives, pipes
│   │   ├── components/          # Shared presentational components
│   │   ├── directives/          # Custom attribute/structural directives
│   │   ├── pipes/               # Custom pipes (formatting, filtering)
│   │   ├── validators/          # Custom form validators
│   │   └── shared.module.ts     # Shared module (imported in feature modules)
│   ├── features/                # Feature modules (lazy-loaded)
│   │   ├── users/               # User management feature
│   │   │   ├── components/      # Feature-specific components
│   │   │   ├── containers/      # Smart/container components
│   │   │   ├── services/        # Feature-scoped services
│   │   │   ├── models/          # Feature-specific interfaces/types
│   │   │   ├── store/           # Feature state management (NgRx)
│   │   │   │   ├── actions/     # NgRx actions
│   │   │   │   ├── effects/     # NgRx effects (side effects)
│   │   │   │   ├── reducers/    # NgRx reducers (state transitions)
│   │   │   │   ├── selectors/   # NgRx selectors (state queries)
│   │   │   │   └── state/       # State interface definitions
│   │   │   ├── users-routing.module.ts
│   │   │   └── users.module.ts
│   │   ├── orders/              # Order management feature
│   │   ├── dashboard/           # Dashboard feature
│   │   └── settings/            # Settings feature
│   ├── layout/                  # Application layout components
│   │   ├── header/
│   │   ├── footer/
│   │   ├── sidebar/
│   │   └── layout.module.ts
│   ├── app-routing.module.ts    # Root routing configuration
│   ├── app.component.ts         # Root component
│   └── app.module.ts            # Root module
├── assets/                      # Static assets (images, fonts, i18n)
├── environments/                # Environment configurations
│   ├── environment.ts           # Development environment
│   ├── environment.staging.ts   # Staging environment
│   └── environment.prod.ts      # Production environment
├── styles/                      # Global styles
│   ├── _variables.scss          # SCSS variables
│   ├── _mixins.scss             # SCSS mixins
│   ├── _typography.scss         # Typography styles
│   └── styles.scss              # Global stylesheet entry
├── index.html
├── main.ts
└── polyfills.ts
```

#### Layer Responsibilities

**Container Components (Smart Components)**
```typescript
/**
 * Container component responsibilities:
 * - Interact with services and state management
 * - Dispatch NgRx actions
 * - Subscribe to state via selectors
 * - Pass data down to presentational components
 * - Handle user events from child components
 * - NO direct DOM manipulation
 * - NO inline styles or complex template logic
 */
@Component({
  selector: 'app-user-list-container',
  template: `
    <app-user-list
      [users]="users$ | async"
      [loading]="loading$ | async"
      [error]="error$ | async"
      (userSelected)="onUserSelected($event)"
      (userDeleted)="onUserDeleted($event)"
      (pageChanged)="onPageChanged($event)">
    </app-user-list>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListContainerComponent implements OnInit, OnDestroy {

  users$: Observable<User[]>;
  loading$: Observable<boolean>;
  error$: Observable<string | null>;

  private readonly destroy$ = new Subject<void>();

  constructor(private readonly store: Store<AppState>) {}

  ngOnInit(): void {
    this.users$ = this.store.select(selectAllUsers);
    this.loading$ = this.store.select(selectUsersLoading);
    this.error$ = this.store.select(selectUsersError);

    this.store.dispatch(UsersActions.loadUsers());
  }

  onUserSelected(user: User): void {
    this.store.dispatch(UsersActions.selectUser({ userId: user.id }));
  }

  onUserDeleted(userId: string): void {
    this.store.dispatch(UsersActions.deleteUser({ userId }));
  }

  onPageChanged(page: number): void {
    this.store.dispatch(UsersActions.loadUsers({ page }));
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

**Presentational Components (Dumb Components)**
```typescript
/**
 * Presentational component responsibilities:
 * - Render UI based on @Input() data
 * - Emit user interactions via @Output() events
 * - NO service injection (except UI-only services like MatDialog)
 * - NO state management interaction
 * - NO HTTP calls
 * - Fully testable with @Input/@Output alone
 */
@Component({
  selector: 'app-user-list',
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListComponent implements OnChanges {

  @Input() users: User[] = [];
  @Input() loading = false;
  @Input() error: string | null = null;

  @Output() userSelected = new EventEmitter<User>();
  @Output() userDeleted = new EventEmitter<string>();
  @Output() pageChanged = new EventEmitter<number>();

  displayedColumns: string[] = ['name', 'email', 'status', 'actions'];
  dataSource = new MatTableDataSource<User>();

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['users'] && this.users) {
      this.dataSource.data = this.users;
    }
  }

  onSelectUser(user: User): void {
    this.userSelected.emit(user);
  }

  onDeleteUser(userId: string): void {
    this.userDeleted.emit(userId);
  }

  onPageChange(event: PageEvent): void {
    this.pageChanged.emit(event.pageIndex + 1);
  }

  trackByUserId(index: number, user: User): string {
    return user.id;
  }
}
```

**Service Layer**
```typescript
/**
 * Service layer responsibilities:
 * - HTTP communication with backend APIs
 * - Data transformation and mapping
 * - Business logic that is not component-specific
 * - Error handling and retry logic
 * - Caching strategies
 * - NO UI logic or DOM manipulation
 */
@Injectable({
  providedIn: 'root'
})
export class UserService {

  private readonly apiUrl = `${environment.apiBaseUrl}/api/v1/users`;

  constructor(
    private readonly http: HttpClient,
    private readonly errorHandler: ErrorHandlerService,
    private readonly logger: LoggerService
  ) {}

  getUsers(params?: UserQueryParams): Observable<PaginatedResponse<User>> {
    const httpParams = this.buildHttpParams(params);

    return this.http.get<PaginatedResponse<UserDto>>(this.apiUrl, { params: httpParams }).pipe(
      map(response => ({
        ...response,
        data: response.data.map(dto => UserMapper.toDomain(dto))
      })),
      tap(response => this.logger.debug('Users fetched', { count: response.data.length })),
      catchError(error => this.errorHandler.handleError<PaginatedResponse<User>>(error, 'getUsers'))
    );
  }

  getUserById(id: string): Observable<User> {
    return this.http.get<UserDto>(`${this.apiUrl}/${encodeURIComponent(id)}`).pipe(
      map(dto => UserMapper.toDomain(dto)),
      catchError(error => this.errorHandler.handleError<User>(error, 'getUserById'))
    );
  }

  createUser(request: CreateUserRequest): Observable<User> {
    return this.http.post<UserDto>(this.apiUrl, request).pipe(
      map(dto => UserMapper.toDomain(dto)),
      tap(user => this.logger.info('User created', { userId: user.id })),
      catchError(error => this.errorHandler.handleError<User>(error, 'createUser'))
    );
  }

  updateUser(id: string, request: UpdateUserRequest): Observable<User> {
    return this.http.put<UserDto>(`${this.apiUrl}/${encodeURIComponent(id)}`, request).pipe(
      map(dto => UserMapper.toDomain(dto)),
      tap(user => this.logger.info('User updated', { userId: user.id })),
      catchError(error => this.errorHandler.handleError<User>(error, 'updateUser'))
    );
  }

  deleteUser(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${encodeURIComponent(id)}`).pipe(
      tap(() => this.logger.info('User deleted', { userId: id })),
      catchError(error => this.errorHandler.handleError<void>(error, 'deleteUser'))
    );
  }

  private buildHttpParams(params?: UserQueryParams): HttpParams {
    let httpParams = new HttpParams();
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          httpParams = httpParams.set(key, String(value));
        }
      });
    }
    return httpParams;
  }
}
```

**NgRx State Management Layer**
```typescript
/**
 * State management responsibilities:
 * - Single source of truth for feature state
 * - Immutable state transitions via reducers
 * - Side effects isolation via effects
 * - Derived state computation via selectors
 * - NO direct HTTP calls in reducers
 * - NO business logic in actions
 */

// --- State Interface ---
export interface UsersState {
  users: User[];
  selectedUserId: string | null;
  loading: boolean;
  error: string | null;
  pagination: PaginationState;
}

export const initialUsersState: UsersState = {
  users: [],
  selectedUserId: null,
  loading: false,
  error: null,
  pagination: {
    currentPage: 1,
    pageSize: 20,
    totalItems: 0,
    totalPages: 0
  }
};

// --- Actions ---
export const UsersActions = createActionGroup({
  source: 'Users',
  events: {
    'Load Users': props<{ page?: number }>(),
    'Load Users Success': props<{ users: User[]; pagination: PaginationState }>(),
    'Load Users Failure': props<{ error: string }>(),
    'Select User': props<{ userId: string }>(),
    'Create User': props<{ request: CreateUserRequest }>(),
    'Create User Success': props<{ user: User }>(),
    'Create User Failure': props<{ error: string }>(),
    'Delete User': props<{ userId: string }>(),
    'Delete User Success': props<{ userId: string }>(),
    'Delete User Failure': props<{ error: string }>()
  }
});

// --- Reducer ---
export const usersReducer = createReducer(
  initialUsersState,

  on(UsersActions.loadUsers, (state): UsersState => ({
    ...state,
    loading: true,
    error: null
  })),

  on(UsersActions.loadUsersSuccess, (state, { users, pagination }): UsersState => ({
    ...state,
    users,
    pagination,
    loading: false,
    error: null
  })),

  on(UsersActions.loadUsersFailure, (state, { error }): UsersState => ({
    ...state,
    loading: false,
    error
  })),

  on(UsersActions.selectUser, (state, { userId }): UsersState => ({
    ...state,
    selectedUserId: userId
  })),

  on(UsersActions.createUserSuccess, (state, { user }): UsersState => ({
    ...state,
    users: [...state.users, user],
    loading: false,
    error: null
  })),

  on(UsersActions.deleteUserSuccess, (state, { userId }): UsersState => ({
    ...state,
    users: state.users.filter(u => u.id !== userId),
    loading: false,
    error: null
  }))
);

// --- Selectors ---
export const selectUsersState = createFeatureSelector<UsersState>('users');

export const selectAllUsers = createSelector(
  selectUsersState,
  (state: UsersState) => state.users
);

export const selectUsersLoading = createSelector(
  selectUsersState,
  (state: UsersState) => state.loading
);

export const selectUsersError = createSelector(
  selectUsersState,
  (state: UsersState) => state.error
);

export const selectSelectedUser = createSelector(
  selectUsersState,
  (state: UsersState) => state.users.find(u => u.id === state.selectedUserId) ?? null
);

export const selectUsersPagination = createSelector(
  selectUsersState,
  (state: UsersState) => state.pagination
);

// --- Effects ---
@Injectable()
export class UsersEffects {

  loadUsers$ = createEffect(() =>
    this.actions$.pipe(
      ofType(UsersActions.loadUsers),
      switchMap(({ page }) =>
        this.userService.getUsers({ page: page ?? 1 }).pipe(
          map(response => UsersActions.loadUsersSuccess({
            users: response.data,
            pagination: response.pagination
          })),
          catchError(error => of(UsersActions.loadUsersFailure({
            error: error.message ?? 'Failed to load users'
          })))
        )
      )
    )
  );

  createUser$ = createEffect(() =>
    this.actions$.pipe(
      ofType(UsersActions.createUser),
      exhaustMap(({ request }) =>
        this.userService.createUser(request).pipe(
          map(user => UsersActions.createUserSuccess({ user })),
          catchError(error => of(UsersActions.createUserFailure({
            error: error.message ?? 'Failed to create user'
          })))
        )
      )
    )
  );

  deleteUser$ = createEffect(() =>
    this.actions$.pipe(
      ofType(UsersActions.deleteUser),
      mergeMap(({ userId }) =>
        this.userService.deleteUser(userId).pipe(
          map(() => UsersActions.deleteUserSuccess({ userId })),
          catchError(error => of(UsersActions.deleteUserFailure({
            error: error.message ?? 'Failed to delete user'
          })))
        )
      )
    )
  );

  constructor(
    private readonly actions$: Actions,
    private readonly userService: UserService
  ) {}
}
```

### 1.2 State Management Strategy Selection

Choosing the right state management approach is critical. Angular offers multiple options at different levels of complexity. The wrong choice leads to either unnecessary boilerplate or unmanageable spaghetti state. Use this decision framework.

#### Decision Matrix

| Criteria | Angular Signals | Service + RxJS Observables | NgRx Signal Store | NgRx Store (Actions/Reducers/Effects) |
|----------|----------------|---------------------------|-------------------|---------------------------------------|
| **Scope** | Component-local UI state | Feature-scoped shared state | Feature-scoped shared state with signal reactivity | Application-wide or cross-feature global state |
| **Complexity** | Low | Low–Medium | Medium | High |
| **Boilerplate** | Minimal | Minimal | Low–Moderate | High (actions, reducers, effects, selectors) |
| **DevTools / Time-travel** | No | No | Partial (Signal Store DevTools plugin) | Full (Redux DevTools, action log, time-travel) |
| **Side Effect Isolation** | Manual | Manual (RxJS operators) | `rxMethod` built-in | Dedicated Effects classes |
| **Team Familiarity Required** | Angular basics | RxJS proficiency | Signals + NgRx concepts | Deep RxJS + NgRx + Redux mental model |
| **Testability** | Simple (set signal, assert) | Moderate (mock observables) | Good (mock store methods) | Excellent (isolated action/reducer/effect tests) |
| **Best For** | Toggles, form state, UI flags, local component state | Feature-level data loading, simple CRUD, caching | Feature stores that benefit from signal reactivity and reduced boilerplate | Enterprise features with complex workflows, audit trails, undo/redo, cross-feature coordination |

#### When to Use Each Approach

##### 1. Angular Signals — Component-Local UI State

**Use when:** State is owned by a single component or a parent-child tree, has no cross-feature consumers, and does not involve async/side-effect orchestration.

**Examples:** Toggling a sidebar, tracking form dirty state, expand/collapse panels, local pagination index.

```typescript
/**
 * Signals for purely local UI state.
 * No service, no store — component owns the state.
 */
@Component({
  selector: 'app-collapsible-panel',
  template: `
    <div class="panel-header" (click)="toggle()">
      <span>{{ title }}</span>
      <mat-icon>{{ isExpanded() ? 'expand_less' : 'expand_more' }}</mat-icon>
    </div>
    @if (isExpanded()) {
      <div class="panel-body">
        <ng-content />
      </div>
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class CollapsiblePanelComponent {
  @Input() title = '';
  @Input() expandedByDefault = false;

  protected readonly isExpanded = signal(false);

  ngOnInit(): void {
    this.isExpanded.set(this.expandedByDefault);
  }

  toggle(): void {
    this.isExpanded.update(v => !v);
  }
}
```

##### 2. Service + RxJS Observables — Feature-Scoped Shared State

**Use when:** Multiple components within a feature share state, the state involves async HTTP operations, but the feature is self-contained and does not require global event coordination or time-travel debugging.

**Examples:** Simple CRUD feature, search with autocomplete, feature-level caching, data loaded from one API and consumed by sibling components.

```typescript
/**
 * Lightweight state management via a service with BehaviorSubjects.
 * Good for features that are straightforward CRUD with shared state.
 */
@Injectable()
export class UserStateService {

  private readonly usersSubject = new BehaviorSubject<User[]>([]);
  private readonly loadingSubject = new BehaviorSubject<boolean>(false);
  private readonly errorSubject = new BehaviorSubject<string | null>(null);

  readonly users$ = this.usersSubject.asObservable();
  readonly loading$ = this.loadingSubject.asObservable();
  readonly error$ = this.errorSubject.asObservable();

  constructor(private readonly userService: UserService) {}

  loadUsers(): void {
    this.loadingSubject.next(true);
    this.errorSubject.next(null);

    this.userService.getUsers().pipe(
      finalize(() => this.loadingSubject.next(false))
    ).subscribe({
      next: response => this.usersSubject.next(response.data),
      error: err => this.errorSubject.next(err.message ?? 'Failed to load users')
    });
  }

  deleteUser(userId: string): void {
    this.userService.deleteUser(userId).subscribe({
      next: () => {
        const updated = this.usersSubject.value.filter(u => u.id !== userId);
        this.usersSubject.next(updated);
      },
      error: err => this.errorSubject.next(err.message ?? 'Failed to delete user')
    });
  }
}

/**
 * Provided at the feature module level — not root.
 * Each lazy-loaded instance gets its own state.
 */
@NgModule({
  providers: [UserStateService]
})
export class UsersModule {}
```

##### 3. NgRx Signal Store — Feature-Scoped State with Signal Reactivity

**Use when:** You want the structure and predictability of a store but prefer Angular Signals over RxJS Observables for template reactivity, and the feature does not need global cross-feature coordination. This is the **recommended default for new feature development** when the team is on Angular 17+.

**Examples:** Feature CRUD with moderate complexity, dashboard widgets with computed derived state, features that benefit from `computed()` signal composition.

```typescript
/**
 * NgRx Signal Store: Combines store structure with signal reactivity.
 * Less boilerplate than traditional NgRx, type-safe, signal-native.
 */
import { signalStore, withState, withComputed, withMethods, patchState } from '@ngrx/signals';
import { rxMethod } from '@ngrx/signals/rxjs-interop';

// --- State type ---
type UsersState = {
  users: User[];
  selectedUserId: string | null;
  loading: boolean;
  error: string | null;
  filter: UserFilter;
};

const initialState: UsersState = {
  users: [],
  selectedUserId: null,
  loading: false,
  error: null,
  filter: { query: '', status: null }
};

// --- Signal Store definition ---
export const UsersStore = signalStore(
  { providedIn: 'root' },

  withState(initialState),

  withComputed((store) => ({
    /** Derived state: filtered users — recomputes only when dependencies change */
    filteredUsers: computed(() => {
      const users = store.users();
      const filter = store.filter();
      return users
        .filter(u => !filter.status || u.status === filter.status)
        .filter(u => !filter.query ||
          u.fullName.toLowerCase().includes(filter.query.toLowerCase()));
    }),

    /** Derived state: selected user object */
    selectedUser: computed(() =>
      store.users().find(u => u.id === store.selectedUserId()) ?? null
    ),

    /** Derived state: count for display */
    totalCount: computed(() => store.users().length)
  })),

  withMethods((store, userService = inject(UserService)) => ({

    /** Synchronous state updates */
    selectUser(userId: string): void {
      patchState(store, { selectedUserId: userId });
    },

    updateFilter(filter: Partial<UserFilter>): void {
      patchState(store, (state) => ({
        filter: { ...state.filter, ...filter }
      }));
    },

    /** Async side effects via rxMethod */
    loadUsers: rxMethod<void>(
      pipe(
        tap(() => patchState(store, { loading: true, error: null })),
        switchMap(() =>
          userService.getUsers().pipe(
            tapResponse({
              next: (response) => patchState(store, {
                users: response.data,
                loading: false
              }),
              error: (error: Error) => patchState(store, {
                loading: false,
                error: error.message
              })
            })
          )
        )
      )
    ),

    deleteUser: rxMethod<string>(
      pipe(
        switchMap((userId) =>
          userService.deleteUser(userId).pipe(
            tapResponse({
              next: () => patchState(store, (state) => ({
                users: state.users.filter(u => u.id !== userId)
              })),
              error: (error: Error) => patchState(store, {
                error: error.message
              })
            })
          )
        )
      )
    )
  }))
);

/**
 * Component consuming Signal Store — uses signals directly in templates.
 * No async pipe needed. No manual subscription management.
 */
@Component({
  selector: 'app-user-list-container',
  template: `
    <app-user-search (queryChanged)="onSearch($event)" />

    @if (store.loading()) {
      <app-loading-spinner />
    }

    @if (store.error(); as error) {
      <app-error-message [message]="error" (retry)="store.loadUsers()" />
    }

    <app-user-list
      [users]="store.filteredUsers()"
      [totalCount]="store.totalCount()"
      (userSelected)="store.selectUser($event.id)"
      (userDeleted)="store.deleteUser($event)">
    </app-user-list>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListContainerComponent implements OnInit {

  protected readonly store = inject(UsersStore);

  ngOnInit(): void {
    this.store.loadUsers();
  }

  onSearch(query: string): void {
    this.store.updateFilter({ query });
  }
}
```

##### 4. NgRx Store (Actions / Reducers / Effects) — Application-Wide Global State

**Use when:** State must be shared across multiple features, the application requires full audit trails of state changes, time-travel debugging is valuable during development, or the domain has complex event-driven workflows (e.g., order checkout spanning cart, payment, inventory, shipping).

**Examples:** Authentication state consumed by every feature, shopping cart shared across product and checkout modules, real-time collaboration state, features requiring undo/redo, complex multi-step wizards with branching logic.

> The full NgRx Store example is provided in Section 1.1 above.

#### Migration Path

For teams with existing traditional NgRx stores, migration to Signal Store can be incremental:

1. **New features** — Use NgRx Signal Store by default (Angular 17+).
2. **Existing features** — Migrate when the feature is next significantly modified. Do not rewrite working stores purely for migration.
3. **Global cross-feature state** — Keep in traditional NgRx Store until the Signal Store interop story matures. Authentication, routing meta-state, and global notification buses remain in the global store.
4. **Hybrid coexistence** — Traditional NgRx Store and Signal Stores can coexist in the same application. Use `selectSignal()` to bridge global store state into signal-based features when needed.

#### Anti-Patterns

```typescript
// ❌ WRONG: NgRx Store for a toggle
this.store.dispatch(SidebarActions.toggleSidebar());
// → Use a signal: sidebarOpen = signal(false);

// ❌ WRONG: Raw BehaviorSubjects for complex cross-feature orchestration
// with 10+ subjects, manual error handling, no event log
// → Use NgRx Store with proper actions, reducers, and effects.

// ❌ WRONG: Signals holding async/observable state without proper loading tracking
readonly users = signal<User[]>([]);
loadUsers(): void {
  this.http.get<User[]>('/api/users').subscribe(u => this.users.set(u));
  // BAD: No loading state, no error handling, silent failures
}
// → Use rxMethod from Signal Store or a service with proper loading/error state.

// ❌ WRONG: Mixing state approaches within the same feature
// Some components use store.select(), others use a BehaviorSubject service,
// a third reads a signal — for the SAME state.
// → One feature, one state management approach.
```

### 1.3 Data Transfer Objects (DTOs) and Domain Models

#### DTO and Domain Model Guidelines

**Why Separate DTOs from Domain Models?**
- Decouple API contract from internal component models
- Control data exposure (security)
- Enable API evolution without breaking internal logic
- Optimize payloads and transform for UI consumption
- Enforce type safety at system boundaries

#### API DTOs (Backend Contract)
```typescript
/**
 * DTO matching the backend API contract.
 * These must mirror the API response shape exactly.
 * NO business logic, NO computed properties.
 */
export interface UserDto {
  readonly id: string;
  readonly email: string;
  readonly first_name: string;        // snake_case from API
  readonly last_name: string;
  readonly phone_number: string | null;
  readonly status: string;
  readonly created_at: string;         // ISO 8601 string from API
  readonly updated_at: string;
  readonly address: AddressDto | null;
}

export interface AddressDto {
  readonly street: string;
  readonly city: string;
  readonly state: string;
  readonly zip_code: string;
  readonly country: string;
}
```

#### Domain Models (Internal Application Contract)
```typescript
/**
 * Domain model used within the application.
 * Follows TypeScript/Angular naming conventions (camelCase).
 * May include computed properties and helper methods.
 */
export interface User {
  readonly id: string;
  readonly email: string;
  readonly firstName: string;           // camelCase for internal use
  readonly lastName: string;
  readonly phoneNumber: string | null;
  readonly status: UserStatus;
  readonly createdAt: Date;             // Parsed Date object
  readonly updatedAt: Date;
  readonly address: Address | null;
  readonly fullName: string;            // Computed property
}

export interface Address {
  readonly street: string;
  readonly city: string;
  readonly state: string;
  readonly zipCode: string;
  readonly country: string;
}

export enum UserStatus {
  Active = 'ACTIVE',
  Inactive = 'INACTIVE',
  Suspended = 'SUSPENDED',
  PendingVerification = 'PENDING_VERIFICATION'
}
```

#### Request DTOs
```typescript
/**
 * Request DTO with validation constraints documented.
 * Used for create/update API calls.
 */
export interface CreateUserRequest {
  readonly email: string;               // Required, valid email, max 255 chars
  readonly firstName: string;           // Required, 2-50 chars
  readonly lastName: string;            // Required, 2-50 chars
  readonly phoneNumber?: string;        // Optional, E.164 format
  readonly address?: CreateAddressRequest;
}

export interface UpdateUserRequest {
  readonly email?: string;
  readonly firstName?: string;
  readonly lastName?: string;
  readonly phoneNumber?: string | null;
  readonly address?: CreateAddressRequest | null;
}

export interface CreateAddressRequest {
  readonly street: string;
  readonly city: string;
  readonly state: string;
  readonly zipCode: string;
  readonly country: string;
}
```

#### DTO Mappers
```typescript
/**
 * Mapper for DTO-Domain conversion.
 * All mapping logic is centralized here.
 * Pure functions — no side effects, fully testable.
 */
export class UserMapper {

  /**
   * Maps API DTO to internal domain model.
   */
  static toDomain(dto: UserDto): User {
    return {
      id: dto.id,
      email: dto.email,
      firstName: dto.first_name,
      lastName: dto.last_name,
      phoneNumber: dto.phone_number,
      status: dto.status as UserStatus,
      createdAt: new Date(dto.created_at),
      updatedAt: new Date(dto.updated_at),
      address: dto.address ? AddressMapper.toDomain(dto.address) : null,
      fullName: `${dto.first_name} ${dto.last_name}`
    };
  }

  /**
   * Maps domain model to API request DTO.
   */
  static toCreateRequest(form: UserFormValue): CreateUserRequest {
    return {
      email: form.email.trim(),
      firstName: form.firstName.trim(),
      lastName: form.lastName.trim(),
      phoneNumber: form.phoneNumber?.trim() || undefined,
      address: form.address ? AddressMapper.toRequest(form.address) : undefined
    };
  }
}

export class AddressMapper {

  static toDomain(dto: AddressDto): Address {
    return {
      street: dto.street,
      city: dto.city,
      state: dto.state,
      zipCode: dto.zip_code,
      country: dto.country
    };
  }

  static toRequest(address: AddressFormValue): CreateAddressRequest {
    return {
      street: address.street.trim(),
      city: address.city.trim(),
      state: address.state.trim(),
      zipCode: address.zipCode.trim(),
      country: address.country.trim()
    };
  }
}
```

### 1.4 Dependency Injection

#### Proper Service Injection Patterns (Mandatory)

```typescript
/**
 * ALWAYS use constructor-based injection with:
 * - private readonly modifier for immutability
 * - Explicit providedIn configuration
 * - Interface-based abstractions where applicable
 */

// ✅ CORRECT: Constructor injection with readonly
@Injectable({
  providedIn: 'root'
})
export class UserService {
  constructor(
    private readonly http: HttpClient,
    private readonly logger: LoggerService,
    private readonly config: AppConfigService
  ) {}
}

// ✅ CORRECT: Feature-scoped service (provided in module)
@Injectable()
export class UserFormService {
  constructor(
    private readonly fb: FormBuilder,
    private readonly validatorService: ValidatorService
  ) {}
}

// ✅ CORRECT: Using injection tokens for configuration
export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL');
export const FEATURE_FLAGS = new InjectionToken<FeatureFlags>('FEATURE_FLAGS');

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  constructor(
    private readonly http: HttpClient,
    @Inject(API_BASE_URL) private readonly baseUrl: string,
    @Inject(FEATURE_FLAGS) private readonly featureFlags: FeatureFlags
  ) {}
}

// ❌ WRONG: Mutable dependency references
@Injectable({
  providedIn: 'root'
})
export class UserService {
  http: HttpClient;  // BAD: Not private, not readonly

  constructor(http: HttpClient) {
    this.http = http;  // BAD: Manual assignment, mutable
  }
}

// ❌ WRONG: Service locator pattern
@Injectable({
  providedIn: 'root'
})
export class UserService {
  constructor(private readonly injector: Injector) {}

  getUsers(): Observable<User[]> {
    // BAD: Service locator anti-pattern — hides dependencies
    const http = this.injector.get(HttpClient);
    return http.get<User[]>('/api/users');
  }
}

// ❌ WRONG: providedIn missing for root-level services
@Injectable()  // BAD: Must specify providedIn for tree-shaking
export class UserService {
  constructor(private readonly http: HttpClient) {}
}
```

#### Hierarchical Injection Scoping

```typescript
/**
 * Root-level singleton: Application-wide shared state
 */
@Injectable({
  providedIn: 'root'
})
export class AuthService {
  // Single instance for entire application
}

/**
 * Feature-module-level: Scoped to a lazy-loaded feature
 * Provided in the feature module's providers array
 */
@NgModule({
  providers: [
    UserFormService,          // New instance per feature module load
    UserValidationService
  ]
})
export class UsersModule {}

/**
 * Component-level: New instance per component instance
 */
@Component({
  selector: 'app-user-editor',
  templateUrl: './user-editor.component.html',
  providers: [UserEditorStateService]  // New instance per component
})
export class UserEditorComponent {
  constructor(private readonly editorState: UserEditorStateService) {}
}
```

### 1.5 Naming Conventions

#### File Naming Standards

| Component Type | Suffix | File Name Example | Purpose |
|----------------|--------|-------------------|---------|
| Component | `.component.ts` | `user-list.component.ts` | UI component |
| Container | `.container.ts` | `user-list.container.ts` | Smart/container component |
| Module | `.module.ts` | `users.module.ts` | Angular module |
| Service | `.service.ts` | `user.service.ts` | Business logic / HTTP |
| Guard | `.guard.ts` | `auth.guard.ts` | Route guard |
| Interceptor | `.interceptor.ts` | `auth.interceptor.ts` | HTTP interceptor |
| Pipe | `.pipe.ts` | `date-format.pipe.ts` | Template pipe |
| Directive | `.directive.ts` | `tooltip.directive.ts` | Custom directive |
| Resolver | `.resolver.ts` | `user.resolver.ts` | Route resolver |
| Validator | `.validator.ts` | `email.validator.ts` | Form validator |
| Model/Interface | `.model.ts` | `user.model.ts` | Type definitions |
| DTO | `.dto.ts` | `user.dto.ts` | API contract types |
| Mapper | `.mapper.ts` | `user.mapper.ts` | DTO-Domain mapping |
| Enum | `.enum.ts` | `user-status.enum.ts` | Enumerations |
| Constants | `.constants.ts` | `api.constants.ts` | Constant values |
| Mock | `.mock.ts` | `user.mock.ts` | Test mock data |
| Spec | `.spec.ts` | `user.service.spec.ts` | Unit test |
| NgRx Actions | `.actions.ts` | `users.actions.ts` | State actions |
| NgRx Reducer | `.reducer.ts` | `users.reducer.ts` | State reducer |
| NgRx Effects | `.effects.ts` | `users.effects.ts` | State side effects |
| NgRx Selectors | `.selectors.ts` | `users.selectors.ts` | State selectors |

#### Class and Symbol Naming Standards

```typescript
/**
 * Naming conventions for Angular symbols
 */

// Components: PascalCase + Component suffix
export class UserListComponent {}
export class OrderDetailComponent {}

// Services: PascalCase + Service suffix
export class UserService {}
export class AuthenticationService {}
export class ErrorHandlerService {}

// Guards: PascalCase + Guard suffix
export class AuthGuard {}
export class RoleGuard {}

// Interceptors: PascalCase + Interceptor suffix
export class AuthInterceptor {}
export class ErrorInterceptor {}
export class LoggingInterceptor {}

// Pipes: PascalCase + Pipe suffix
export class DateFormatPipe {}
export class CurrencyFormatPipe {}

// Directives: PascalCase + Directive suffix
export class TooltipDirective {}
export class HighlightDirective {}

// Models/Interfaces: PascalCase, NO prefix (no "I" prefix)
export interface User {}            // ✅ CORRECT
export interface CreateUserRequest {}
export interface IUser {}           // ❌ WRONG: No Hungarian notation

// Enums: PascalCase, singular
export enum UserStatus {}           // ✅ CORRECT
export enum OrderType {}
export enum UserStatuses {}         // ❌ WRONG: Do not pluralize enums

// Constants: UPPER_SNAKE_CASE for primitives, camelCase for objects
export const MAX_RETRY_ATTEMPTS = 3;
export const API_BASE_URL = '/api/v1';
export const defaultPagination: PaginationConfig = { page: 1, size: 20 };
```

#### Method Naming Standards

```typescript
/**
 * Method naming conventions
 */
export class UserService {

  // Query methods: get*, find*, search*, list*, fetch*, load*, count*, exists*
  getUsers(): Observable<User[]> { /* ... */ }
  getUserById(id: string): Observable<User> { /* ... */ }
  searchUsers(query: string): Observable<User[]> { /* ... */ }
  findUserByEmail(email: string): Observable<User | null> { /* ... */ }
  fetchActiveUsers(): Observable<User[]> { /* ... */ }
  countActiveUsers(): Observable<number> { /* ... */ }

  // Command methods: create*, update*, delete*, save*, remove*, submit*
  createUser(request: CreateUserRequest): Observable<User> { /* ... */ }
  updateUser(id: string, request: UpdateUserRequest): Observable<User> { /* ... */ }
  deleteUser(id: string): Observable<void> { /* ... */ }
  submitUserForm(form: UserFormValue): Observable<User> { /* ... */ }

  // Boolean predicates: is*, has*, can*, should*
  isUserActive(user: User): boolean { /* ... */ }
  hasPermission(permission: string): Observable<boolean> { /* ... */ }
  canDeleteUser(user: User): boolean { /* ... */ }

  // Event handlers in components: on* prefix
  // onUserSelected(user: User): void {}
  // onFormSubmit(): void {}
  // onPageChanged(page: number): void {}

  // Lifecycle: standard Angular names only (ngOnInit, ngOnDestroy, etc.)
}
```

### 1.6 Module Design

#### Core Module (Singleton — Imported Once)
```typescript
/**
 * Core module: Application-wide singletons.
 * Imported ONLY in AppModule.
 * Contains services, interceptors, guards that must be singletons.
 */
@NgModule({
  imports: [
    CommonModule,
    HttpClientModule
  ],
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: ErrorInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: LoggingInterceptor,
      multi: true
    },
    {
      provide: ErrorHandler,
      useClass: GlobalErrorHandler
    }
  ]
})
export class CoreModule {

  /**
   * Guard against re-importing CoreModule.
   * Ensures singleton services remain single instances.
   */
  constructor(@Optional() @SkipSelf() parentModule: CoreModule) {
    if (parentModule) {
      throw new Error(
        'CoreModule is already loaded. Import it only in AppModule.'
      );
    }
  }
}
```

#### Shared Module (Reusable — Imported in Feature Modules)
```typescript
/**
 * Shared module: Reusable components, directives, pipes.
 * Imported in every feature module that needs shared UI elements.
 * MUST NOT have providers (to avoid multiple service instances).
 * MUST export everything it declares plus commonly used Angular modules.
 */
@NgModule({
  declarations: [
    // Shared components
    LoadingSpinnerComponent,
    ConfirmDialogComponent,
    PaginationComponent,
    EmptyStateComponent,
    ErrorMessageComponent,

    // Shared directives
    TooltipDirective,
    AutoFocusDirective,
    DebounceClickDirective,

    // Shared pipes
    DateFormatPipe,
    TruncatePipe,
    PhoneFormatPipe,
    CurrencyFormatPipe
  ],
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    RouterModule,
    MaterialModule        // Angular Material re-export module
  ],
  exports: [
    // Re-export Angular modules
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    RouterModule,
    MaterialModule,

    // Export shared declarations
    LoadingSpinnerComponent,
    ConfirmDialogComponent,
    PaginationComponent,
    EmptyStateComponent,
    ErrorMessageComponent,
    TooltipDirective,
    AutoFocusDirective,
    DebounceClickDirective,
    DateFormatPipe,
    TruncatePipe,
    PhoneFormatPipe,
    CurrencyFormatPipe
  ]
})
export class SharedModule {}
```

#### Feature Module (Lazy-Loaded)
```typescript
/**
 * Feature module: Self-contained feature with lazy loading.
 * Each feature module manages its own routing, components, services, and state.
 */
@NgModule({
  declarations: [
    // Containers (smart components)
    UserListContainerComponent,
    UserDetailContainerComponent,
    UserFormContainerComponent,

    // Presentational (dumb components)
    UserListComponent,
    UserDetailComponent,
    UserFormComponent,
    UserCardComponent,
    UserStatusBadgeComponent
  ],
  imports: [
    SharedModule,
    UsersRoutingModule,
    StoreModule.forFeature('users', usersReducer),
    EffectsModule.forFeature([UsersEffects])
  ],
  providers: [
    UserFormService,
    UserValidationService
  ]
})
export class UsersModule {}

/**
 * Feature routing module with lazy loading
 */
const routes: Routes = [
  {
    path: '',
    component: UserListContainerComponent,
    data: { title: 'Users', breadcrumb: 'Users' }
  },
  {
    path: 'create',
    component: UserFormContainerComponent,
    canActivate: [AuthGuard, RoleGuard],
    data: { roles: ['ADMIN', 'USER_MANAGER'], title: 'Create User' }
  },
  {
    path: ':id',
    component: UserDetailContainerComponent,
    resolve: { user: UserResolver }
  },
  {
    path: ':id/edit',
    component: UserFormContainerComponent,
    canActivate: [AuthGuard, RoleGuard],
    canDeactivate: [UnsavedChangesGuard],
    data: { roles: ['ADMIN', 'USER_MANAGER'], title: 'Edit User' }
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class UsersRoutingModule {}
```

#### App Routing (Root — Lazy Loading Entry)
```typescript
/**
 * Root routing module with lazy-loaded feature modules.
 * All feature modules are loaded on demand to reduce initial bundle size.
 */
const routes: Routes = [
  {
    path: '',
    redirectTo: 'dashboard',
    pathMatch: 'full'
  },
  {
    path: 'dashboard',
    loadChildren: () =>
      import('./features/dashboard/dashboard.module').then(m => m.DashboardModule),
    canActivate: [AuthGuard]
  },
  {
    path: 'users',
    loadChildren: () =>
      import('./features/users/users.module').then(m => m.UsersModule),
    canActivate: [AuthGuard]
  },
  {
    path: 'orders',
    loadChildren: () =>
      import('./features/orders/orders.module').then(m => m.OrdersModule),
    canActivate: [AuthGuard]
  },
  {
    path: 'settings',
    loadChildren: () =>
      import('./features/settings/settings.module').then(m => m.SettingsModule),
    canActivate: [AuthGuard, RoleGuard],
    data: { roles: ['ADMIN'] }
  },
  {
    path: 'auth',
    loadChildren: () =>
      import('./features/auth/auth.module').then(m => m.AuthModule)
  },
  {
    path: '**',
    redirectTo: 'dashboard'
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, {
    preloadingStrategy: PreloadAllModules,
    scrollPositionRestoration: 'top',
    paramsInheritanceStrategy: 'always'
  })],
  exports: [RouterModule]
})
export class AppRoutingModule {}
```

### 1.7 Reactive Forms Standards

#### Form Design Pattern

```typescript
/**
 * Reactive form service: Centralizes form creation,
 * validation, and value mapping for a feature.
 */
@Injectable()
export class UserFormService {

  constructor(
    private readonly fb: FormBuilder,
    private readonly validatorService: UserValidatorService
  ) {}

  /**
   * Creates a typed reactive form with all validations.
   */
  createForm(user?: User): FormGroup<UserFormControls> {
    return this.fb.group<UserFormControls>({
      email: this.fb.control(user?.email ?? '', {
        nonNullable: true,
        validators: [
          Validators.required,
          Validators.email,
          Validators.maxLength(255)
        ],
        asyncValidators: [
          this.validatorService.uniqueEmailValidator(user?.email)
        ],
        updateOn: 'blur'
      }),
      firstName: this.fb.control(user?.firstName ?? '', {
        nonNullable: true,
        validators: [
          Validators.required,
          Validators.minLength(2),
          Validators.maxLength(50),
          Validators.pattern(/^[a-zA-Z\s\-']+$/)
        ]
      }),
      lastName: this.fb.control(user?.lastName ?? '', {
        nonNullable: true,
        validators: [
          Validators.required,
          Validators.minLength(2),
          Validators.maxLength(50),
          Validators.pattern(/^[a-zA-Z\s\-']+$/)
        ]
      }),
      phoneNumber: this.fb.control(user?.phoneNumber ?? '', {
        validators: [
          Validators.pattern(/^\+?[1-9]\d{1,14}$/)  // E.164 format
        ]
      }),
      address: this.fb.group<AddressFormControls>({
        street: this.fb.control('', { nonNullable: true, validators: [Validators.required] }),
        city: this.fb.control('', { nonNullable: true, validators: [Validators.required] }),
        state: this.fb.control('', { nonNullable: true, validators: [Validators.required] }),
        zipCode: this.fb.control('', {
          nonNullable: true,
          validators: [Validators.required, Validators.pattern(/^\d{5}(-\d{4})?$/)]
        }),
        country: this.fb.control('', { nonNullable: true, validators: [Validators.required] })
      })
    });
  }

  /**
   * Extracts typed form value for API submission.
   */
  getFormValue(form: FormGroup<UserFormControls>): CreateUserRequest {
    const value = form.getRawValue();
    return UserMapper.toCreateRequest(value);
  }
}

/**
 * Strongly-typed form control interfaces
 */
export interface UserFormControls {
  email: FormControl<string>;
  firstName: FormControl<string>;
  lastName: FormControl<string>;
  phoneNumber: FormControl<string>;
  address: FormGroup<AddressFormControls>;
}

export interface AddressFormControls {
  street: FormControl<string>;
  city: FormControl<string>;
  state: FormControl<string>;
  zipCode: FormControl<string>;
  country: FormControl<string>;
}
```

#### Custom Async Validator
```typescript
/**
 * Custom async validator: Checks email uniqueness against the API.
 * Debounced to avoid excessive API calls.
 */
@Injectable()
export class UserValidatorService {

  constructor(private readonly userService: UserService) {}

  uniqueEmailValidator(currentEmail?: string): AsyncValidatorFn {
    return (control: AbstractControl): Observable<ValidationErrors | null> => {
      if (!control.value || control.value === currentEmail) {
        return of(null);
      }

      return timer(400).pipe(
        switchMap(() => this.userService.findUserByEmail(control.value)),
        map(user => (user ? { emailTaken: true } : null)),
        catchError(() => of(null))
      );
    };
  }
}
```

---

## 2. Architectural Patterns

### 2.1 SOLID Principles in Angular

#### 2.1.1 Single Responsibility Principle (SRP)

**Definition:** A class should have only one reason to change, meaning it should have only one job or responsibility.

#### ❌ Violation Example

```typescript
/**
 * BAD: Component handles HTTP, validation, formatting, and UI state
 */
@Component({
  selector: 'app-user-manager',
  template: `...`
})
export class UserManagerComponent implements OnInit {

  users: User[] = [];
  loading = false;
  error = '';

  constructor(private readonly http: HttpClient) {}

  ngOnInit(): void {
    this.loadUsers();
  }

  // Responsibility 1: HTTP communication
  loadUsers(): void {
    this.loading = true;
    this.http.get<any[]>('/api/users').subscribe({
      next: (data) => {
        this.users = data.map(d => ({
          ...d,
          fullName: d.first_name + ' ' + d.last_name,
          createdAt: new Date(d.created_at)
        }));
        this.loading = false;
      },
      error: (err) => {
        this.error = err.message;
        this.loading = false;
      }
    });
  }

  // Responsibility 2: Validation
  validateEmail(email: string): boolean {
    return /^[A-Za-z0-9+_.-]+@(.+)$/.test(email);
  }

  // Responsibility 3: Formatting
  formatDate(date: Date): string {
    return date.toLocaleDateString('en-US', {
      year: 'numeric', month: 'long', day: 'numeric'
    });
  }

  // Responsibility 4: CSV Export
  exportToCsv(): void {
    const csv = this.users.map(u =>
      `${u.firstName},${u.lastName},${u.email}`
    ).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    saveAs(blob, 'users.csv');
  }
}
```

#### ✅ Correct Implementation

```typescript
/**
 * Single Responsibility: UI orchestration only
 */
@Component({
  selector: 'app-user-list-container',
  template: `
    <app-user-list
      [users]="users$ | async"
      [loading]="loading$ | async"
      [error]="error$ | async"
      (export)="onExport()">
    </app-user-list>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListContainerComponent implements OnInit {

  users$: Observable<User[]>;
  loading$: Observable<boolean>;
  error$: Observable<string | null>;

  constructor(
    private readonly store: Store<AppState>,
    private readonly exportService: CsvExportService
  ) {}

  ngOnInit(): void {
    this.users$ = this.store.select(selectAllUsers);
    this.loading$ = this.store.select(selectUsersLoading);
    this.error$ = this.store.select(selectUsersError);
    this.store.dispatch(UsersActions.loadUsers());
  }

  onExport(): void {
    this.users$.pipe(take(1)).subscribe(users =>
      this.exportService.exportUsers(users)
    );
  }
}

/**
 * Single Responsibility: HTTP communication
 */
@Injectable({ providedIn: 'root' })
export class UserService {

  private readonly apiUrl = `${environment.apiBaseUrl}/api/v1/users`;

  constructor(private readonly http: HttpClient) {}

  getUsers(): Observable<User[]> {
    return this.http.get<UserDto[]>(this.apiUrl).pipe(
      map(dtos => dtos.map(UserMapper.toDomain))
    );
  }
}

/**
 * Single Responsibility: Data mapping
 */
export class UserMapper {
  static toDomain(dto: UserDto): User {
    return {
      id: dto.id,
      email: dto.email,
      firstName: dto.first_name,
      lastName: dto.last_name,
      fullName: `${dto.first_name} ${dto.last_name}`,
      createdAt: new Date(dto.created_at),
      status: dto.status as UserStatus
    };
  }
}

/**
 * Single Responsibility: CSV export
 */
@Injectable({ providedIn: 'root' })
export class CsvExportService {

  exportUsers(users: User[]): void {
    const header = 'First Name,Last Name,Email\n';
    const rows = users.map(u =>
      `${this.escapeField(u.firstName)},${this.escapeField(u.lastName)},${this.escapeField(u.email)}`
    ).join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8' });
    saveAs(blob, `users-${Date.now()}.csv`);
  }

  private escapeField(field: string): string {
    if (field.includes(',') || field.includes('"') || field.includes('\n')) {
      return `"${field.replace(/"/g, '""')}"`;
    }
    return field;
  }
}

/**
 * Single Responsibility: Date formatting (as a Pipe)
 */
@Pipe({ name: 'appDateFormat' })
export class DateFormatPipe implements PipeTransform {
  transform(value: Date | string, format = 'longDate'): string {
    const date = typeof value === 'string' ? new Date(value) : value;
    return date.toLocaleDateString('en-US', {
      year: 'numeric', month: 'long', day: 'numeric'
    });
  }
}
```

#### 2.1.2 Open/Closed Principle (OCP)

**Definition:** Software entities should be open for extension but closed for modification.

#### ❌ Violation Example

```typescript
/**
 * BAD: Adding a new notification type requires modifying this service
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {

  show(type: string, message: string): void {
    if (type === 'success') {
      this.showSuccessToast(message);
    } else if (type === 'error') {
      this.showErrorToast(message);
    } else if (type === 'warning') {
      this.showWarningBanner(message);
    } else if (type === 'info') {
      // NEW: had to modify class to add info type
      this.showInfoSnackbar(message);
    }
  }

  private showSuccessToast(message: string): void { /* ... */ }
  private showErrorToast(message: string): void { /* ... */ }
  private showWarningBanner(message: string): void { /* ... */ }
  private showInfoSnackbar(message: string): void { /* ... */ }
}
```

#### ✅ Correct Implementation (Strategy Pattern via DI)

```typescript
/**
 * Strategy interface (open for extension)
 */
export interface NotificationStrategy {
  readonly type: string;
  show(message: string, options?: NotificationOptions): void;
}

/**
 * Injection token for notification strategies
 */
export const NOTIFICATION_STRATEGIES =
  new InjectionToken<NotificationStrategy[]>('NOTIFICATION_STRATEGIES');

/**
 * Concrete implementations
 */
@Injectable()
export class SuccessToastStrategy implements NotificationStrategy {
  readonly type = 'success';

  constructor(private readonly snackBar: MatSnackBar) {}

  show(message: string): void {
    this.snackBar.open(message, 'Close', {
      duration: 3000,
      panelClass: ['toast-success']
    });
  }
}

@Injectable()
export class ErrorToastStrategy implements NotificationStrategy {
  readonly type = 'error';

  constructor(private readonly snackBar: MatSnackBar) {}

  show(message: string): void {
    this.snackBar.open(message, 'Dismiss', {
      duration: 0, // Persistent until dismissed
      panelClass: ['toast-error']
    });
  }
}

@Injectable()
export class WarningBannerStrategy implements NotificationStrategy {
  readonly type = 'warning';

  constructor(private readonly bannerService: BannerService) {}

  show(message: string): void {
    this.bannerService.showWarning(message);
  }
}

/**
 * NEW strategy — no modification to existing code
 */
@Injectable()
export class InfoSnackbarStrategy implements NotificationStrategy {
  readonly type = 'info';

  constructor(private readonly snackBar: MatSnackBar) {}

  show(message: string): void {
    this.snackBar.open(message, 'OK', {
      duration: 5000,
      panelClass: ['toast-info']
    });
  }
}

/**
 * Notification service (closed for modification)
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {

  private readonly strategyMap: Map<string, NotificationStrategy>;

  constructor(
    @Inject(NOTIFICATION_STRATEGIES)
    private readonly strategies: NotificationStrategy[]
  ) {
    this.strategyMap = new Map(
      strategies.map(s => [s.type, s])
    );
  }

  show(type: string, message: string, options?: NotificationOptions): void {
    const strategy = this.strategyMap.get(type);
    if (!strategy) {
      throw new Error(`Unsupported notification type: ${type}`);
    }
    strategy.show(message, options);
  }
}

/**
 * Module configuration — extend by adding new strategies
 */
@NgModule({
  providers: [
    SuccessToastStrategy,
    ErrorToastStrategy,
    WarningBannerStrategy,
    InfoSnackbarStrategy,
    {
      provide: NOTIFICATION_STRATEGIES,
      useFactory: (
        success: SuccessToastStrategy,
        error: ErrorToastStrategy,
        warning: WarningBannerStrategy,
        info: InfoSnackbarStrategy
      ) => [success, error, warning, info],
      deps: [SuccessToastStrategy, ErrorToastStrategy, WarningBannerStrategy, InfoSnackbarStrategy]
    }
  ]
})
export class NotificationModule {}
```

#### 2.1.3 Liskov Substitution Principle (LSP)

**Definition:** Objects of a superclass should be replaceable with objects of a subclass without breaking the application.

#### ❌ Violation Example

```typescript
/**
 * BAD: ReadOnlyStorageService violates the contract of StorageService
 */
export abstract class StorageService {
  abstract getItem(key: string): string | null;
  abstract setItem(key: string, value: string): void;
  abstract removeItem(key: string): void;
}

export class LocalStorageService extends StorageService {
  getItem(key: string): string | null {
    return localStorage.getItem(key);
  }
  setItem(key: string, value: string): void {
    localStorage.setItem(key, value);
  }
  removeItem(key: string): void {
    localStorage.removeItem(key);
  }
}

export class ReadOnlyStorageService extends StorageService {
  getItem(key: string): string | null {
    return sessionStorage.getItem(key);
  }
  setItem(key: string, value: string): void {
    // Violates LSP — callers expect this to work
    throw new Error('Storage is read-only');
  }
  removeItem(key: string): void {
    // Violates LSP — callers expect this to work
    throw new Error('Storage is read-only');
  }
}
```

#### ✅ Correct Implementation

```typescript
/**
 * Segregated interfaces following LSP
 */
export interface ReadableStorage {
  getItem(key: string): string | null;
}

export interface WritableStorage {
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface FullStorage extends ReadableStorage, WritableStorage {}

/**
 * LocalStorage (full read-write)
 */
@Injectable({ providedIn: 'root' })
export class LocalStorageService implements FullStorage {
  getItem(key: string): string | null {
    return localStorage.getItem(key);
  }
  setItem(key: string, value: string): void {
    localStorage.setItem(key, value);
  }
  removeItem(key: string): void {
    localStorage.removeItem(key);
  }
}

/**
 * SessionStorage (full read-write)
 */
@Injectable({ providedIn: 'root' })
export class SessionStorageService implements FullStorage {
  getItem(key: string): string | null {
    return sessionStorage.getItem(key);
  }
  setItem(key: string, value: string): void {
    sessionStorage.setItem(key, value);
  }
  removeItem(key: string): void {
    sessionStorage.removeItem(key);
  }
}

/**
 * In-memory read-only configuration (only implements ReadableStorage)
 */
@Injectable({ providedIn: 'root' })
export class ConfigStorageService implements ReadableStorage {
  private readonly config = new Map<string, string>();

  constructor() {
    this.config.set('theme', 'dark');
    this.config.set('locale', 'en-US');
  }

  getItem(key: string): string | null {
    return this.config.get(key) ?? null;
  }
}

/**
 * Service that reads configuration — accepts any ReadableStorage
 */
@Injectable({ providedIn: 'root' })
export class ThemeService {
  constructor(@Inject(READABLE_STORAGE) private readonly storage: ReadableStorage) {}

  getTheme(): string {
    return this.storage.getItem('theme') ?? 'light';
  }
}

/**
 * Service that persists user preferences — requires FullStorage
 */
@Injectable({ providedIn: 'root' })
export class PreferenceService {
  constructor(@Inject(FULL_STORAGE) private readonly storage: FullStorage) {}

  setPreference(key: string, value: string): void {
    this.storage.setItem(`pref_${key}`, value);
  }

  getPreference(key: string): string | null {
    return this.storage.getItem(`pref_${key}`);
  }
}
```

#### 2.1.4 Interface Segregation Principle (ISP)

**Definition:** Clients should not be forced to depend on interfaces they don't use.

#### ❌ Violation Example

```typescript
/**
 * BAD: Fat interface forces implementors to provide methods they don't need
 */
export interface DataService<T> {
  getAll(): Observable<T[]>;
  getById(id: string): Observable<T>;
  create(entity: T): Observable<T>;
  update(id: string, entity: Partial<T>): Observable<T>;
  delete(id: string): Observable<void>;
  export(format: 'csv' | 'pdf'): Observable<Blob>;
  import(file: File): Observable<T[]>;
  bulkDelete(ids: string[]): Observable<void>;
  archive(id: string): Observable<T>;
  restore(id: string): Observable<T>;
}

/**
 * BAD: AuditLogService forced to implement export/import/archive/restore
 * which don't apply to audit logs
 */
export class AuditLogService implements DataService<AuditLog> {
  getAll(): Observable<AuditLog[]> { /* ... */ }
  getById(id: string): Observable<AuditLog> { /* ... */ }
  create(entity: AuditLog): Observable<AuditLog> {
    throw new Error('Audit logs are system-generated');
  }
  update(id: string, entity: Partial<AuditLog>): Observable<AuditLog> {
    throw new Error('Audit logs are immutable');
  }
  delete(id: string): Observable<void> {
    throw new Error('Audit logs cannot be deleted');
  }
  export(format: 'csv' | 'pdf'): Observable<Blob> {
    throw new Error('Not supported');
  }
  import(file: File): Observable<AuditLog[]> {
    throw new Error('Not supported');
  }
  bulkDelete(ids: string[]): Observable<void> {
    throw new Error('Not supported');
  }
  archive(id: string): Observable<AuditLog> {
    throw new Error('Not supported');
  }
  restore(id: string): Observable<AuditLog> {
    throw new Error('Not supported');
  }
}
```

#### ✅ Correct Implementation

```typescript
/**
 * Segregated interfaces — each client depends only on what it needs
 */
export interface Readable<T> {
  getAll(): Observable<T[]>;
  getById(id: string): Observable<T>;
}

export interface Writable<T> {
  create(entity: T): Observable<T>;
  update(id: string, entity: Partial<T>): Observable<T>;
  delete(id: string): Observable<void>;
}

export interface BulkOperable<T> {
  bulkDelete(ids: string[]): Observable<void>;
}

export interface Exportable<T> {
  export(format: 'csv' | 'pdf'): Observable<Blob>;
}

export interface Importable<T> {
  import(file: File): Observable<T[]>;
}

export interface Archivable<T> {
  archive(id: string): Observable<T>;
  restore(id: string): Observable<T>;
}

/**
 * Full CRUD service composes multiple interfaces
 */
@Injectable({ providedIn: 'root' })
export class UserService implements Readable<User>, Writable<User>,
    BulkOperable<User>, Exportable<User> {

  getAll(): Observable<User[]> { /* ... */ }
  getById(id: string): Observable<User> { /* ... */ }
  create(entity: User): Observable<User> { /* ... */ }
  update(id: string, entity: Partial<User>): Observable<User> { /* ... */ }
  delete(id: string): Observable<void> { /* ... */ }
  bulkDelete(ids: string[]): Observable<void> { /* ... */ }
  export(format: 'csv' | 'pdf'): Observable<Blob> { /* ... */ }
}

/**
 * Read-only service only implements Readable
 */
@Injectable({ providedIn: 'root' })
export class AuditLogService implements Readable<AuditLog> {
  getAll(): Observable<AuditLog[]> { /* ... */ }
  getById(id: string): Observable<AuditLog> { /* ... */ }
  // No need to implement methods that don't apply
}

/**
 * Component that only reads — depends on Readable, not full CRUD
 */
@Component({ selector: 'app-audit-log-viewer', template: '...' })
export class AuditLogViewerComponent implements OnInit {
  logs$: Observable<AuditLog[]>;

  constructor(private readonly auditService: AuditLogService) {}

  ngOnInit(): void {
    this.logs$ = this.auditService.getAll();
  }
}
```

#### 2.1.5 Dependency Inversion Principle (DIP)

**Definition:** High-level modules should not depend on low-level modules. Both should depend on abstractions.

#### ❌ Violation Example

```typescript
/**
 * BAD: High-level component depends directly on low-level implementations
 */
@Component({
  selector: 'app-order-summary',
  template: '...'
})
export class OrderSummaryComponent implements OnInit {

  constructor(
    private readonly http: HttpClient  // BAD: Direct dependency on HTTP
  ) {}

  ngOnInit(): void {
    // BAD: Component knows about API URLs, response shape, mapping
    this.http.get<any>('/api/v1/orders/123').subscribe(data => {
      this.order = {
        id: data.order_id,
        total: data.total_amount,
        status: data.order_status
      };
    });

    // BAD: Component directly uses localStorage
    const savedTheme = localStorage.getItem('theme');
  }
}
```

#### ✅ Correct Implementation

```typescript
/**
 * Abstraction: Analytics tracking contract
 */
export abstract class AnalyticsTracker {
  abstract trackEvent(event: string, properties?: Record<string, unknown>): void;
  abstract trackPageView(page: string): void;
}

/**
 * Low-level: Google Analytics implementation
 */
@Injectable()
export class GoogleAnalyticsTracker extends AnalyticsTracker {

  trackEvent(event: string, properties?: Record<string, unknown>): void {
    gtag('event', event, properties);
  }

  trackPageView(page: string): void {
    gtag('config', environment.gaTrackingId, { page_path: page });
  }
}

/**
 * Low-level: Mixpanel implementation (swap without changing consumers)
 */
@Injectable()
export class MixpanelTracker extends AnalyticsTracker {

  constructor(private readonly mixpanel: MixpanelService) {
    super();
  }

  trackEvent(event: string, properties?: Record<string, unknown>): void {
    this.mixpanel.track(event, properties);
  }

  trackPageView(page: string): void {
    this.mixpanel.track('Page View', { page });
  }
}

/**
 * Low-level: Noop implementation for development/testing
 */
@Injectable()
export class NoopAnalyticsTracker extends AnalyticsTracker {
  trackEvent(): void { /* No-op */ }
  trackPageView(): void { /* No-op */ }
}

/**
 * High-level: Component depends on abstraction, not implementation
 */
@Component({
  selector: 'app-order-summary',
  template: '...',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OrderSummaryComponent implements OnInit {

  order$: Observable<Order>;

  constructor(
    private readonly orderService: OrderService,         // Abstracted HTTP
    private readonly analytics: AnalyticsTracker,         // Abstraction
    private readonly storage: FullStorage                 // Abstraction
  ) {}

  ngOnInit(): void {
    this.order$ = this.orderService.getOrderById('123');
    this.analytics.trackPageView('/orders/123');
  }
}

/**
 * Module configuration: Swap implementations via environment
 */
@NgModule({
  providers: [
    {
      provide: AnalyticsTracker,
      useClass: environment.production
        ? GoogleAnalyticsTracker
        : NoopAnalyticsTracker
    }
  ]
})
export class AnalyticsModule {}
```

### 2.2 Design Patterns in Angular

#### 2.2.1 Creational Patterns

##### 2.2.1.1 Singleton Pattern

**Purpose:** Ensure a service has only one instance application-wide.

**Angular Implementation:** Services with `providedIn: 'root'` are singletons by default.

```typescript
/**
 * Singleton using Angular DI (Recommended)
 */
@Injectable({
  providedIn: 'root'  // Angular ensures single instance via tree-shakable DI
})
export class AppConfigService {

  private readonly config: AppConfig;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    this.config = Object.freeze(config);  // Immutable configuration
  }

  get apiBaseUrl(): string {
    return this.config.apiBaseUrl;
  }

  get featureFlags(): FeatureFlags {
    return this.config.featureFlags;
  }
}

/**
 * Singleton state management (NgRx Store is a singleton by design)
 */
@NgModule({
  imports: [
    StoreModule.forRoot({}, {
      runtimeChecks: {
        strictStateImmutability: true,
        strictActionImmutability: true,
        strictStateSerializability: true,
        strictActionSerializability: true
      }
    }),
    EffectsModule.forRoot([]),
    StoreDevtoolsModule.instrument({
      maxAge: 25,
      logOnly: environment.production
    })
  ]
})
export class AppStoreModule {}

/**
 * Guard against accidental multi-instance (for CoreModule pattern)
 */
@NgModule({
  providers: [/* singleton services */]
})
export class CoreModule {
  constructor(@Optional() @SkipSelf() parentModule: CoreModule) {
    if (parentModule) {
      throw new Error('CoreModule is already loaded. Import it only in AppModule.');
    }
  }
}
```

##### 2.2.1.2 Factory Pattern

**Purpose:** Create objects dynamically based on runtime configuration or context.

```typescript
/**
 * Injection token for the factory product
 */
export const DATA_EXPORTER = new InjectionToken<DataExporter>('DATA_EXPORTER');

/**
 * Product interface
 */
export interface DataExporter {
  export(data: unknown[]): Observable<Blob>;
  readonly mimeType: string;
  readonly fileExtension: string;
}

/**
 * Concrete products
 */
@Injectable()
export class CsvExporter implements DataExporter {
  readonly mimeType = 'text/csv';
  readonly fileExtension = 'csv';

  export(data: unknown[]): Observable<Blob> {
    const csv = this.convertToCsv(data);
    return of(new Blob([csv], { type: this.mimeType }));
  }

  private convertToCsv(data: unknown[]): string {
    if (data.length === 0) return '';
    const headers = Object.keys(data[0] as object).join(',');
    const rows = data.map(row =>
      Object.values(row as object).map(v => `"${String(v)}"`).join(',')
    );
    return [headers, ...rows].join('\n');
  }
}

@Injectable()
export class PdfExporter implements DataExporter {
  readonly mimeType = 'application/pdf';
  readonly fileExtension = 'pdf';

  export(data: unknown[]): Observable<Blob> {
    // PDF generation logic (e.g., using jsPDF)
    return of(new Blob([], { type: this.mimeType }));
  }
}

@Injectable()
export class ExcelExporter implements DataExporter {
  readonly mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  readonly fileExtension = 'xlsx';

  export(data: unknown[]): Observable<Blob> {
    // Excel generation using SheetJS
    return of(new Blob([], { type: this.mimeType }));
  }
}

/**
 * Factory service
 */
@Injectable({ providedIn: 'root' })
export class DataExporterFactory {

  private readonly exporterMap = new Map<string, DataExporter>();

  constructor(
    private readonly csvExporter: CsvExporter,
    private readonly pdfExporter: PdfExporter,
    private readonly excelExporter: ExcelExporter
  ) {
    this.exporterMap.set('csv', csvExporter);
    this.exporterMap.set('pdf', pdfExporter);
    this.exporterMap.set('excel', excelExporter);
  }

  getExporter(format: string): DataExporter {
    const exporter = this.exporterMap.get(format.toLowerCase());
    if (!exporter) {
      throw new Error(`Unsupported export format: ${format}`);
    }
    return exporter;
  }
}

/**
 * Usage in component
 */
@Component({
  selector: 'app-data-export',
  template: `
    <button mat-button [matMenuTriggerFor]="exportMenu">Export</button>
    <mat-menu #exportMenu="matMenu">
      <button mat-menu-item (click)="onExport('csv')">CSV</button>
      <button mat-menu-item (click)="onExport('pdf')">PDF</button>
      <button mat-menu-item (click)="onExport('excel')">Excel</button>
    </mat-menu>
  `
})
export class DataExportComponent {

  @Input() data: unknown[] = [];

  constructor(private readonly exporterFactory: DataExporterFactory) {}

  onExport(format: string): void {
    const exporter = this.exporterFactory.getExporter(format);
    exporter.export(this.data).subscribe(blob => {
      saveAs(blob, `export-${Date.now()}.${exporter.fileExtension}`);
    });
  }
}
```

##### 2.2.1.3 Builder Pattern

**Purpose:** Construct complex objects step by step with a fluent API.

```typescript
/**
 * Complex API query builder
 */
export class ApiQueryBuilder {

  private params: Record<string, string> = {};
  private headers: Record<string, string> = {};
  private _page = 1;
  private _pageSize = 20;
  private _sortField: string | null = null;
  private _sortDirection: 'asc' | 'desc' = 'asc';
  private filters: Array<{ field: string; operator: string; value: string }> = [];

  static create(): ApiQueryBuilder {
    return new ApiQueryBuilder();
  }

  page(page: number): this {
    this._page = page;
    return this;
  }

  pageSize(size: number): this {
    this._pageSize = size;
    return this;
  }

  sortBy(field: string, direction: 'asc' | 'desc' = 'asc'): this {
    this._sortField = field;
    this._sortDirection = direction;
    return this;
  }

  filter(field: string, operator: string, value: string): this {
    this.filters.push({ field, operator, value });
    return this;
  }

  withHeader(key: string, value: string): this {
    this.headers[key] = value;
    return this;
  }

  withParam(key: string, value: string): this {
    this.params[key] = value;
    return this;
  }

  build(): { params: HttpParams; headers: HttpHeaders } {
    let httpParams = new HttpParams()
      .set('page', String(this._page))
      .set('pageSize', String(this._pageSize));

    if (this._sortField) {
      httpParams = httpParams
        .set('sortBy', this._sortField)
        .set('sortDirection', this._sortDirection);
    }

    this.filters.forEach((f, i) => {
      httpParams = httpParams
        .set(`filter[${i}].field`, f.field)
        .set(`filter[${i}].operator`, f.operator)
        .set(`filter[${i}].value`, f.value);
    });

    Object.entries(this.params).forEach(([key, value]) => {
      httpParams = httpParams.set(key, value);
    });

    const httpHeaders = new HttpHeaders(this.headers);

    return { params: httpParams, headers: httpHeaders };
  }
}

/**
 * Usage
 */
@Injectable({ providedIn: 'root' })
export class OrderService {

  constructor(private readonly http: HttpClient) {}

  searchOrders(criteria: OrderSearchCriteria): Observable<PaginatedResponse<Order>> {
    const { params, headers } = ApiQueryBuilder.create()
      .page(criteria.page)
      .pageSize(criteria.pageSize)
      .sortBy(criteria.sortField, criteria.sortDirection)
      .filter('status', 'eq', criteria.status)
      .filter('createdAt', 'gte', criteria.fromDate)
      .filter('createdAt', 'lte', criteria.toDate)
      .withHeader('X-Correlation-ID', crypto.randomUUID())
      .build();

    return this.http.get<PaginatedResponse<Order>>(`${this.apiUrl}/orders`, { params, headers });
  }
}
```

#### 2.2.2 Structural Patterns

##### 2.2.2.1 Adapter Pattern

**Purpose:** Convert the interface of a class into another interface clients expect.

```typescript
/**
 * Target interface (what the application expects)
 */
export interface LoggerService {
  debug(message: string, context?: Record<string, unknown>): void;
  info(message: string, context?: Record<string, unknown>): void;
  warn(message: string, context?: Record<string, unknown>): void;
  error(message: string, error?: Error, context?: Record<string, unknown>): void;
}

/**
 * Adaptee: Third-party logging library (e.g., Datadog)
 */
declare class DatadogRum {
  static addAction(name: string, context?: object): void;
  static addError(error: Error, context?: object): void;
  static setGlobalContextProperty(key: string, value: unknown): void;
}

/**
 * Adapter: Wraps Datadog RUM API behind our LoggerService interface
 */
@Injectable()
export class DatadogLoggerAdapter implements LoggerService {

  debug(message: string, context?: Record<string, unknown>): void {
    if (!environment.production) {
      console.debug(`[DEBUG] ${message}`, context);
    }
    DatadogRum.addAction(message, { level: 'debug', ...context });
  }

  info(message: string, context?: Record<string, unknown>): void {
    DatadogRum.addAction(message, { level: 'info', ...context });
  }

  warn(message: string, context?: Record<string, unknown>): void {
    console.warn(`[WARN] ${message}`, context);
    DatadogRum.addAction(message, { level: 'warn', ...context });
  }

  error(message: string, error?: Error, context?: Record<string, unknown>): void {
    console.error(`[ERROR] ${message}`, error, context);
    if (error) {
      DatadogRum.addError(error, { message, ...context });
    }
  }
}

/**
 * Alternative adapter: Console-only for local development
 */
@Injectable()
export class ConsoleLoggerAdapter implements LoggerService {

  debug(message: string, context?: Record<string, unknown>): void {
    console.debug(`[DEBUG] ${message}`, context);
  }

  info(message: string, context?: Record<string, unknown>): void {
    console.info(`[INFO] ${message}`, context);
  }

  warn(message: string, context?: Record<string, unknown>): void {
    console.warn(`[WARN] ${message}`, context);
  }

  error(message: string, error?: Error, context?: Record<string, unknown>): void {
    console.error(`[ERROR] ${message}`, error, context);
  }
}

/**
 * Injection token and module configuration
 */
export const LOGGER = new InjectionToken<LoggerService>('LoggerService');

@NgModule({
  providers: [
    {
      provide: LOGGER,
      useClass: environment.production
        ? DatadogLoggerAdapter
        : ConsoleLoggerAdapter
    }
  ]
})
export class LoggingModule {}

/**
 * Usage: Client code works with unified interface
 */
@Injectable({ providedIn: 'root' })
export class UserService {
  constructor(
    private readonly http: HttpClient,
    @Inject(LOGGER) private readonly logger: LoggerService
  ) {}

  getUsers(): Observable<User[]> {
    this.logger.info('Fetching users');
    return this.http.get<UserDto[]>(this.apiUrl).pipe(
      tap(users => this.logger.debug('Users fetched', { count: users.length })),
      catchError(error => {
        this.logger.error('Failed to fetch users', error);
        return throwError(() => error);
      })
    );
  }
}
```

##### 2.2.2.2 Decorator Pattern

**Purpose:** Attach additional responsibilities to an object dynamically.

```typescript
/**
 * Base HTTP service interface
 */
export abstract class ApiClient {
  abstract get<T>(url: string, options?: object): Observable<T>;
  abstract post<T>(url: string, body: unknown, options?: object): Observable<T>;
  abstract put<T>(url: string, body: unknown, options?: object): Observable<T>;
  abstract delete<T>(url: string, options?: object): Observable<T>;
}

/**
 * Concrete implementation
 */
@Injectable()
export class HttpApiClient extends ApiClient {

  constructor(private readonly http: HttpClient) { super(); }

  get<T>(url: string, options?: object): Observable<T> {
    return this.http.get<T>(url, options);
  }

  post<T>(url: string, body: unknown, options?: object): Observable<T> {
    return this.http.post<T>(url, body, options);
  }

  put<T>(url: string, body: unknown, options?: object): Observable<T> {
    return this.http.put<T>(url, body, options);
  }

  delete<T>(url: string, options?: object): Observable<T> {
    return this.http.delete<T>(url, options);
  }
}

/**
 * Logging decorator
 */
@Injectable()
export class LoggingApiClient extends ApiClient {

  constructor(
    private readonly wrapped: HttpApiClient,
    @Inject(LOGGER) private readonly logger: LoggerService
  ) { super(); }

  get<T>(url: string, options?: object): Observable<T> {
    const start = performance.now();
    this.logger.debug('HTTP GET', { url });

    return this.wrapped.get<T>(url, options).pipe(
      tap(() =>
        this.logger.debug('HTTP GET complete', {
          url,
          duration: `${(performance.now() - start).toFixed(2)}ms`
        })
      ),
      catchError(error => {
        this.logger.error('HTTP GET failed', error, { url });
        return throwError(() => error);
      })
    );
  }

  post<T>(url: string, body: unknown, options?: object): Observable<T> {
    this.logger.debug('HTTP POST', { url });
    return this.wrapped.post<T>(url, body, options);
  }

  put<T>(url: string, body: unknown, options?: object): Observable<T> {
    this.logger.debug('HTTP PUT', { url });
    return this.wrapped.put<T>(url, body, options);
  }

  delete<T>(url: string, options?: object): Observable<T> {
    this.logger.debug('HTTP DELETE', { url });
    return this.wrapped.delete<T>(url, options);
  }
}

/**
 * Caching decorator
 */
@Injectable()
export class CachingApiClient extends ApiClient {

  private readonly cache = new Map<string, { data: unknown; expiry: number }>();
  private readonly defaultTtl = 5 * 60 * 1000; // 5 minutes

  constructor(private readonly wrapped: ApiClient) { super(); }

  get<T>(url: string, options?: object): Observable<T> {
    const cached = this.cache.get(url);
    if (cached && cached.expiry > Date.now()) {
      return of(cached.data as T);
    }

    return this.wrapped.get<T>(url, options).pipe(
      tap(data => this.cache.set(url, { data, expiry: Date.now() + this.defaultTtl }))
    );
  }

  post<T>(url: string, body: unknown, options?: object): Observable<T> {
    this.cache.clear(); // Invalidate cache on mutations
    return this.wrapped.post<T>(url, body, options);
  }

  put<T>(url: string, body: unknown, options?: object): Observable<T> {
    this.cache.clear();
    return this.wrapped.put<T>(url, body, options);
  }

  delete<T>(url: string, options?: object): Observable<T> {
    this.cache.clear();
    return this.wrapped.delete<T>(url, options);
  }
}
```

##### 2.2.2.3 Facade Pattern

**Purpose:** Provide a simplified interface to a complex subsystem.

```typescript
/**
 * Complex subsystem services
 */
@Injectable({ providedIn: 'root' })
export class OrderApiService {
  createOrder(request: CreateOrderRequest): Observable<Order> { /* ... */ }
  getOrderById(id: string): Observable<Order> { /* ... */ }
}

@Injectable({ providedIn: 'root' })
export class PaymentApiService {
  processPayment(request: PaymentRequest): Observable<PaymentResult> { /* ... */ }
  getPaymentStatus(transactionId: string): Observable<PaymentStatus> { /* ... */ }
}

@Injectable({ providedIn: 'root' })
export class InventoryApiService {
  checkStock(productId: string, quantity: number): Observable<StockStatus> { /* ... */ }
  reserveStock(orderId: string, items: OrderItem[]): Observable<ReservationResult> { /* ... */ }
}

@Injectable({ providedIn: 'root' })
export class ShippingApiService {
  calculateShipping(request: ShippingRequest): Observable<ShippingQuote> { /* ... */ }
  createShipment(orderId: string): Observable<Shipment> { /* ... */ }
}

/**
 * Facade: Simplifies complex order checkout workflow
 */
@Injectable({ providedIn: 'root' })
export class CheckoutFacade {

  constructor(
    private readonly orderApi: OrderApiService,
    private readonly paymentApi: PaymentApiService,
    private readonly inventoryApi: InventoryApiService,
    private readonly shippingApi: ShippingApiService,
    @Inject(LOGGER) private readonly logger: LoggerService
  ) {}

  /**
   * Single method orchestrates the entire checkout process:
   * 1. Validate inventory
   * 2. Calculate shipping
   * 3. Create order
   * 4. Reserve stock
   * 5. Process payment
   */
  checkout(request: CheckoutRequest): Observable<CheckoutResult> {
    this.logger.info('Starting checkout', { items: request.items.length });

    return this.validateInventory(request.items).pipe(
      switchMap(stockStatus => {
        if (!stockStatus.allAvailable) {
          return throwError(() => new InsufficientStockError(stockStatus.unavailableItems));
        }
        return this.shippingApi.calculateShipping({
          items: request.items,
          address: request.shippingAddress
        });
      }),
      switchMap(shippingQuote =>
        this.orderApi.createOrder({
          items: request.items,
          shippingAddress: request.shippingAddress,
          shippingCost: shippingQuote.cost
        })
      ),
      switchMap(order =>
        this.inventoryApi.reserveStock(order.id, request.items).pipe(
          map(reservation => ({ order, reservation }))
        )
      ),
      switchMap(({ order }) =>
        this.paymentApi.processPayment({
          orderId: order.id,
          amount: order.totalAmount,
          paymentMethod: request.paymentMethod
        }).pipe(
          map(payment => ({
            orderId: order.id,
            orderNumber: order.orderNumber,
            paymentTransactionId: payment.transactionId,
            totalAmount: order.totalAmount,
            status: 'CONFIRMED' as const
          }))
        )
      ),
      tap(result => this.logger.info('Checkout complete', { orderId: result.orderId })),
      catchError(error => {
        this.logger.error('Checkout failed', error);
        return throwError(() => error);
      })
    );
  }

  private validateInventory(items: CartItem[]): Observable<StockValidationResult> {
    const checks$ = items.map(item =>
      this.inventoryApi.checkStock(item.productId, item.quantity)
    );
    return forkJoin(checks$).pipe(
      map(results => ({
        allAvailable: results.every(r => r.available),
        unavailableItems: results
          .filter(r => !r.available)
          .map(r => r.productId)
      }))
    );
  }
}

/**
 * Component uses the Facade — no knowledge of subsystem complexity
 */
@Component({
  selector: 'app-checkout',
  template: '...',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class CheckoutComponent {

  checkoutResult$: Observable<CheckoutResult> | null = null;

  constructor(private readonly checkoutFacade: CheckoutFacade) {}

  onSubmitCheckout(request: CheckoutRequest): void {
    this.checkoutResult$ = this.checkoutFacade.checkout(request);
  }
}
```

#### 2.2.3 Behavioral Patterns

##### 2.2.3.1 Observer Pattern

**Purpose:** Define a one-to-many dependency so that when one object changes state, all dependents are notified.

**Angular Implementation:** RxJS Observables and Subject variants are the native Observer pattern.

```typescript
/**
 * Notification bus using BehaviorSubject / Subject
 */
@Injectable({ providedIn: 'root' })
export class NotificationBus {

  private readonly notificationSubject = new Subject<AppNotification>();
  private readonly unreadCountSubject = new BehaviorSubject<number>(0);

  /** Stream of notifications for subscribers */
  readonly notifications$ = this.notificationSubject.asObservable();

  /** Current unread count (BehaviorSubject replays latest value) */
  readonly unreadCount$ = this.unreadCountSubject.asObservable();

  emit(notification: AppNotification): void {
    this.notificationSubject.next(notification);
    this.unreadCountSubject.next(this.unreadCountSubject.value + 1);
  }

  markAllRead(): void {
    this.unreadCountSubject.next(0);
  }
}

/**
 * Publisher: Any service can emit notifications
 */
@Injectable({ providedIn: 'root' })
export class OrderService {

  constructor(
    private readonly http: HttpClient,
    private readonly notificationBus: NotificationBus
  ) {}

  createOrder(request: CreateOrderRequest): Observable<Order> {
    return this.http.post<Order>(this.apiUrl, request).pipe(
      tap(order => this.notificationBus.emit({
        type: 'success',
        title: 'Order Created',
        message: `Order #${order.orderNumber} has been placed.`,
        timestamp: new Date()
      }))
    );
  }
}

/**
 * Subscriber: Component reacts to notifications
 */
@Component({
  selector: 'app-notification-bell',
  template: `
    <button mat-icon-button [matBadge]="unreadCount$ | async" matBadgeColor="warn">
      <mat-icon>notifications</mat-icon>
    </button>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class NotificationBellComponent {
  readonly unreadCount$ = this.notificationBus.unreadCount$;

  constructor(private readonly notificationBus: NotificationBus) {}
}
```

##### 2.2.3.2 Mediator Pattern (via NgRx Store)

**Purpose:** Reduce chaotic dependencies between components by routing all communication through a central mediator.

```typescript
/**
 * NgRx Store acts as the Mediator:
 * - Components dispatch Actions (commands)
 * - Store updates State via Reducers
 * - Effects handle side effects (API calls, navigation)
 * - Components select State via Selectors
 *
 * Components never communicate directly —
 * all coordination flows through the Store.
 */

// Component A dispatches an action
@Component({ selector: 'app-product-filter' })
export class ProductFilterComponent {
  constructor(private readonly store: Store) {}

  onFilterChanged(filter: ProductFilter): void {
    this.store.dispatch(ProductActions.filterChanged({ filter }));
  }
}

// Component B reacts to the state change
@Component({ selector: 'app-product-list' })
export class ProductListComponent {
  filteredProducts$ = this.store.select(selectFilteredProducts);

  constructor(private readonly store: Store) {}
}

// Component C also reacts to the same state change
@Component({ selector: 'app-product-count' })
export class ProductCountComponent {
  count$ = this.store.select(selectFilteredProductCount);

  constructor(private readonly store: Store) {}
}

// Effects mediate external interactions
@Injectable()
export class ProductEffects {
  filterChanged$ = createEffect(() =>
    this.actions$.pipe(
      ofType(ProductActions.filterChanged),
      debounceTime(300),
      switchMap(({ filter }) =>
        this.productService.searchProducts(filter).pipe(
          map(products => ProductActions.loadProductsSuccess({ products })),
          catchError(error => of(ProductActions.loadProductsFailure({ error: error.message })))
        )
      )
    )
  );

  constructor(
    private readonly actions$: Actions,
    private readonly productService: ProductService
  ) {}
}
```

##### 2.2.3.3 Strategy Pattern (via Angular DI)

**Purpose:** Define a family of algorithms, encapsulate each one, and make them interchangeable at runtime.

```typescript
/**
 * Strategy interface for form validation
 */
export interface ValidationStrategy {
  validate(form: FormGroup): ValidationResult;
  readonly validationLevel: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationWarning[];
}

/**
 * Basic validation strategy (quick inline checks)
 */
@Injectable()
export class BasicValidationStrategy implements ValidationStrategy {
  readonly validationLevel = 'basic';

  validate(form: FormGroup): ValidationResult {
    const errors: ValidationError[] = [];

    if (form.invalid) {
      Object.entries(form.controls).forEach(([name, control]) => {
        if (control.errors) {
          Object.entries(control.errors).forEach(([errorKey, errorValue]) => {
            errors.push({ field: name, rule: errorKey, message: this.getMessage(name, errorKey) });
          });
        }
      });
    }

    return { valid: errors.length === 0, errors, warnings: [] };
  }

  private getMessage(field: string, errorKey: string): string {
    const messages: Record<string, string> = {
      required: `${field} is required`,
      email: `${field} must be a valid email`,
      minlength: `${field} is too short`,
      maxlength: `${field} is too long`
    };
    return messages[errorKey] ?? `${field} is invalid`;
  }
}

/**
 * Strict validation strategy (checks business rules, cross-field validation)
 */
@Injectable()
export class StrictValidationStrategy implements ValidationStrategy {
  readonly validationLevel = 'strict';

  validate(form: FormGroup): ValidationResult {
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];
    const value = form.getRawValue();

    // Basic validation
    if (form.invalid) {
      errors.push({ field: 'form', rule: 'invalid', message: 'Form has validation errors' });
    }

    // Cross-field business rules
    if (value.startDate && value.endDate && value.startDate > value.endDate) {
      errors.push({
        field: 'dateRange',
        rule: 'dateOrder',
        message: 'Start date must be before end date'
      });
    }

    // Business warnings
    if (value.amount > 10000) {
      warnings.push({
        field: 'amount',
        message: 'High-value transaction requires manager approval'
      });
    }

    return { valid: errors.length === 0, errors, warnings };
  }
}

/**
 * Context: Uses interchangeable validation strategy
 */
@Injectable()
export class FormSubmissionService {

  constructor(
    @Inject(VALIDATION_STRATEGY)
    private readonly validationStrategy: ValidationStrategy,
    @Inject(LOGGER) private readonly logger: LoggerService
  ) {}

  submit(form: FormGroup): Observable<SubmissionResult> {
    const result = this.validationStrategy.validate(form);

    this.logger.info('Form validation', {
      level: this.validationStrategy.validationLevel,
      valid: result.valid,
      errorCount: result.errors.length
    });

    if (!result.valid) {
      return throwError(() => new FormValidationError(result.errors));
    }

    if (result.warnings.length > 0) {
      this.logger.warn('Form submitted with warnings', { warnings: result.warnings });
    }

    return of({ success: true, warnings: result.warnings });
  }
}

/**
 * Module configuration: Switch strategy per environment or feature flag
 */
@NgModule({
  providers: [
    {
      provide: VALIDATION_STRATEGY,
      useClass: environment.production
        ? StrictValidationStrategy
        : BasicValidationStrategy
    }
  ]
})
export class ValidationModule {}
```

##### 2.2.3.4 Template Method Pattern (via Abstract Base Components)

**Purpose:** Define the skeleton of an algorithm in a base class, deferring some steps to subclasses.

```typescript
/**
 * Abstract base class: Defines the workflow template.
 * Subclasses implement specific steps.
 */
@Directive()
export abstract class BaseListComponent<T> implements OnInit, OnDestroy {

  items$!: Observable<T[]>;
  loading$!: Observable<boolean>;
  error$!: Observable<string | null>;

  protected readonly destroy$ = new Subject<void>();

  /** Template method: defines the workflow */
  ngOnInit(): void {
    this.items$ = this.selectItems();
    this.loading$ = this.selectLoading();
    this.error$ = this.selectError();
    this.dispatchLoad();
    this.setupAdditionalSubscriptions();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  /** Steps to be implemented by subclasses */
  protected abstract selectItems(): Observable<T[]>;
  protected abstract selectLoading(): Observable<boolean>;
  protected abstract selectError(): Observable<string | null>;
  protected abstract dispatchLoad(): void;

  /** Optional hook: subclasses can override for additional setup */
  protected setupAdditionalSubscriptions(): void {
    // Default: no-op. Subclasses can override.
  }

  /** Shared behavior */
  onRefresh(): void {
    this.dispatchLoad();
  }

  onItemSelected(item: T): void {
    this.handleItemSelection(item);
  }

  protected abstract handleItemSelection(item: T): void;
}

/**
 * Concrete implementation: User list
 */
@Component({
  selector: 'app-user-list-container',
  template: `
    <app-user-list
      [users]="items$ | async"
      [loading]="loading$ | async"
      [error]="error$ | async"
      (userSelected)="onItemSelected($event)"
      (refresh)="onRefresh()">
    </app-user-list>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListContainerComponent extends BaseListComponent<User> {

  constructor(
    private readonly store: Store<AppState>,
    private readonly router: Router
  ) {
    super();
  }

  protected selectItems(): Observable<User[]> {
    return this.store.select(selectAllUsers);
  }

  protected selectLoading(): Observable<boolean> {
    return this.store.select(selectUsersLoading);
  }

  protected selectError(): Observable<string | null> {
    return this.store.select(selectUsersError);
  }

  protected dispatchLoad(): void {
    this.store.dispatch(UsersActions.loadUsers());
  }

  protected handleItemSelection(user: User): void {
    this.router.navigate(['/users', user.id]);
  }
}

/**
 * Concrete implementation: Order list (same workflow, different data)
 */
@Component({
  selector: 'app-order-list-container',
  template: `
    <app-order-list
      [orders]="items$ | async"
      [loading]="loading$ | async"
      [error]="error$ | async"
      (orderSelected)="onItemSelected($event)"
      (refresh)="onRefresh()">
    </app-order-list>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OrderListContainerComponent extends BaseListComponent<Order> {

  constructor(
    private readonly store: Store<AppState>,
    private readonly router: Router
  ) {
    super();
  }

  protected selectItems(): Observable<Order[]> {
    return this.store.select(selectAllOrders);
  }

  protected selectLoading(): Observable<boolean> {
    return this.store.select(selectOrdersLoading);
  }

  protected selectError(): Observable<string | null> {
    return this.store.select(selectOrdersError);
  }

  protected dispatchLoad(): void {
    this.store.dispatch(OrdersActions.loadOrders());
  }

  protected handleItemSelection(order: Order): void {
    this.router.navigate(['/orders', order.id]);
  }

  /** Override optional hook for order-specific subscriptions */
  protected override setupAdditionalSubscriptions(): void {
    // Auto-refresh orders every 30 seconds
    interval(30000).pipe(
      takeUntil(this.destroy$)
    ).subscribe(() => this.dispatchLoad());
  }
}
```

---

## 3. Security Standards

### 3.1 Application Security

#### 3.1.1 Cross-Site Scripting (XSS) Prevention

Angular's template engine sanitizes values by default. These standards ensure that protection is never bypassed.

##### Mandatory Rules

- **Never bypass Angular's built-in sanitization** unless explicitly approved by a security review.
- **Never use `innerHTML` with unsanitized user input.** Use Angular's `DomSanitizer` only when the source is trusted and the content has been validated server-side.
- **Always use Angular's template binding** (`{{ }}`, `[property]`) instead of direct DOM manipulation.
- **Never use `document.createElement`, `element.innerHTML`, or `jQuery`** to inject content into the DOM.

```typescript
/**
 * ❌ WRONG: Bypassing sanitization without justification
 */
@Component({
  selector: 'app-unsafe',
  template: `<div [innerHTML]="userContent"></div>`
})
export class UnsafeComponent {
  // BAD: Direct user input rendered as HTML — XSS vector
  userContent = '<img src=x onerror="alert(1)">';
}

/**
 * ❌ WRONG: Blindly trusting content
 */
@Component({
  selector: 'app-bypass',
  template: `<div [innerHTML]="trustedHtml"></div>`
})
export class BypassComponent {
  constructor(private readonly sanitizer: DomSanitizer) {}

  // BAD: Trusting user input without server-side validation
  trustedHtml = this.sanitizer.bypassSecurityTrustHtml(this.getUserInput());

  getUserInput(): string {
    return '<script>document.location="https://evil.com"</script>';
  }
}

/**
 * ✅ CORRECT: Let Angular sanitize automatically
 */
@Component({
  selector: 'app-safe',
  template: `
    <p>{{ userContent }}</p>
    <div [textContent]="userContent"></div>
  `
})
export class SafeComponent {
  // Angular automatically escapes interpolated values
  userContent = '<script>alert("xss")</script>';
  // Rendered as literal text: <script>alert("xss")</script>
}

/**
 * ✅ CORRECT: Sanitize only when necessary, with explicit pipe
 */
@Pipe({ name: 'safeHtml' })
export class SafeHtmlPipe implements PipeTransform {

  constructor(private readonly sanitizer: DomSanitizer) {}

  /**
   * Use ONLY for server-rendered, pre-sanitized HTML (e.g., CMS content).
   * Never use for user-generated input that hasn't been sanitized server-side.
   */
  transform(value: string): SafeHtml {
    return this.sanitizer.bypassSecurityTrustHtml(value);
  }
}
```

##### Content Security Policy (CSP)

Enforce a strict CSP header on all application responses. The CSP must be configured at the server/CDN/reverse-proxy level.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{RANDOM}';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https://cdn.company.com;
  font-src 'self' https://fonts.googleapis.com;
  connect-src 'self' https://api.company.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

**Angular-specific CSP rules:**
- Avoid `'unsafe-eval'` — Angular does not require `eval()` in AOT-compiled production builds.
- Set `"budgets"` in `angular.json` to flag unexpected script growth that may indicate injected code.
- Use nonce-based script loading for any inline scripts required by analytics or third-party SDKs.

#### 3.1.2 Cross-Site Request Forgery (CSRF/XSRF) Protection

Angular's `HttpClient` has built-in XSRF support. It must be enabled and configured for all applications.

```typescript
/**
 * XSRF Configuration — AppModule
 * Angular reads the XSRF token from a cookie and attaches it
 * as a custom header on every mutating HTTP request.
 */
@NgModule({
  imports: [
    HttpClientModule,
    HttpClientXsrfModule.withOptions({
      cookieName: 'XSRF-TOKEN',      // Cookie name set by the backend
      headerName: 'X-XSRF-TOKEN'     // Header name expected by the backend
    })
  ]
})
export class AppModule {}
```

**Mandatory rules:**
- The backend **must** set the `XSRF-TOKEN` cookie on initial page load or login response.
- The backend **must** validate the `X-XSRF-TOKEN` header on all state-changing requests (POST, PUT, PATCH, DELETE).
- The `SameSite` attribute on session cookies **must** be set to `Strict` or `Lax`.
- Cookies **must** have `Secure` and `HttpOnly` flags in production.

#### 3.1.3 Authentication & Authorization

##### Route-Level Authorization with Guards

```typescript
/**
 * Authentication Guard — Protects routes requiring a logged-in user.
 * Redirects to login if no valid session/token exists.
 */
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {

  constructor(
    private readonly authService: AuthService,
    private readonly router: Router
  ) {}

  canActivate(route: ActivatedRouteSnapshot, state: RouterStateSnapshot): Observable<boolean> {
    return this.authService.isAuthenticated$.pipe(
      take(1),
      map(isAuthenticated => {
        if (!isAuthenticated) {
          this.router.navigate(['/auth/login'], {
            queryParams: { returnUrl: state.url }
          });
          return false;
        }
        return true;
      })
    );
  }
}

/**
 * Role-Based Authorization Guard — Restricts routes to specific roles.
 */
@Injectable({ providedIn: 'root' })
export class RoleGuard implements CanActivate {

  constructor(
    private readonly authService: AuthService,
    private readonly router: Router
  ) {}

  canActivate(route: ActivatedRouteSnapshot): Observable<boolean> {
    const requiredRoles: string[] = route.data['roles'] ?? [];

    if (requiredRoles.length === 0) {
      return of(true);
    }

    return this.authService.userRoles$.pipe(
      take(1),
      map(userRoles => {
        const hasRole = requiredRoles.some(role => userRoles.includes(role));
        if (!hasRole) {
          this.router.navigate(['/unauthorized']);
          return false;
        }
        return true;
      })
    );
  }
}

/**
 * Route configuration with guards
 */
const routes: Routes = [
  {
    path: 'admin',
    loadChildren: () => import('./features/admin/admin.module').then(m => m.AdminModule),
    canActivate: [AuthGuard, RoleGuard],
    data: { roles: ['ADMIN'] }
  },
  {
    path: 'users',
    loadChildren: () => import('./features/users/users.module').then(m => m.UsersModule),
    canActivate: [AuthGuard, RoleGuard],
    data: { roles: ['ADMIN', 'USER_MANAGER'] }
  }
];
```

##### Component-Level Authorization with Structural Directive

```typescript
/**
 * Structural directive to conditionally render UI based on user roles.
 * Hides elements the user is not authorized to see.
 *
 * Usage:
 *   <button *appHasRole="'ADMIN'">Delete All Users</button>
 *   <button *appHasRole="['ADMIN', 'USER_MANAGER']">Edit User</button>
 *
 * IMPORTANT: This is a UI convenience. The backend MUST enforce
 * authorization independently. Never rely solely on UI hiding for security.
 */
@Directive({ selector: '[appHasRole]' })
export class HasRoleDirective implements OnInit, OnDestroy {

  @Input('appHasRole') requiredRoles: string | string[] = [];

  private readonly destroy$ = new Subject<void>();

  constructor(
    private readonly templateRef: TemplateRef<unknown>,
    private readonly viewContainer: ViewContainerRef,
    private readonly authService: AuthService
  ) {}

  ngOnInit(): void {
    const roles = Array.isArray(this.requiredRoles)
      ? this.requiredRoles
      : [this.requiredRoles];

    this.authService.userRoles$.pipe(
      takeUntil(this.destroy$)
    ).subscribe(userRoles => {
      const hasRole = roles.some(role => userRoles.includes(role));
      this.viewContainer.clear();
      if (hasRole) {
        this.viewContainer.createEmbeddedView(this.templateRef);
      }
    });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

##### JWT Token Management

```typescript
/**
 * Authentication service — Manages JWT tokens securely.
 *
 * Rules:
 * - Access tokens stored in memory only (never localStorage/sessionStorage).
 * - Refresh tokens stored in HttpOnly, Secure, SameSite cookies (set by backend).
 * - Tokens are never logged, never exposed in URLs, never sent to third-party services.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {

  private readonly currentUserSubject = new BehaviorSubject<AuthUser | null>(null);
  private readonly isAuthenticatedSubject = new BehaviorSubject<boolean>(false);
  private accessToken: string | null = null;

  readonly currentUser$ = this.currentUserSubject.asObservable();
  readonly isAuthenticated$ = this.isAuthenticatedSubject.asObservable();
  readonly userRoles$ = this.currentUser$.pipe(
    map(user => user?.roles ?? [])
  );

  constructor(
    private readonly http: HttpClient,
    private readonly router: Router,
    @Inject(LOGGER) private readonly logger: LoggerService
  ) {}

  /**
   * Login: Exchange credentials for tokens.
   * Access token stored in memory; refresh token set by backend as HttpOnly cookie.
   */
  login(credentials: LoginRequest): Observable<AuthUser> {
    return this.http.post<LoginResponse>(
      `${environment.apiBaseUrl}/api/v1/auth/login`,
      credentials,
      { withCredentials: true }  // Allows cookies to be set
    ).pipe(
      tap(response => {
        this.accessToken = response.accessToken;
        const user = this.decodeToken(response.accessToken);
        this.currentUserSubject.next(user);
        this.isAuthenticatedSubject.next(true);
        this.logger.info('User logged in', { userId: user.id });
      }),
      map(response => this.decodeToken(response.accessToken))
    );
  }

  /**
   * Silent refresh: Use HttpOnly refresh token cookie to get new access token.
   */
  refreshToken(): Observable<string> {
    return this.http.post<RefreshResponse>(
      `${environment.apiBaseUrl}/api/v1/auth/refresh`,
      {},
      { withCredentials: true }
    ).pipe(
      tap(response => {
        this.accessToken = response.accessToken;
        const user = this.decodeToken(response.accessToken);
        this.currentUserSubject.next(user);
      }),
      map(response => response.accessToken),
      catchError(error => {
        this.logger.warn('Token refresh failed, logging out');
        this.logout();
        return throwError(() => error);
      })
    );
  }

  /**
   * Logout: Clear tokens and redirect.
   */
  logout(): void {
    this.accessToken = null;
    this.currentUserSubject.next(null);
    this.isAuthenticatedSubject.next(false);

    // Call backend to invalidate refresh token
    this.http.post(
      `${environment.apiBaseUrl}/api/v1/auth/logout`,
      {},
      { withCredentials: true }
    ).subscribe();

    this.router.navigate(['/auth/login']);
    this.logger.info('User logged out');
  }

  /**
   * Get the current access token (for the AuthInterceptor).
   */
  getAccessToken(): string | null {
    return this.accessToken;
  }

  private decodeToken(token: string): AuthUser {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return {
      id: payload.sub,
      email: payload.email,
      firstName: payload.given_name,
      lastName: payload.family_name,
      roles: payload.roles ?? [],
      permissions: payload.permissions ?? [],
      expiresAt: new Date(payload.exp * 1000)
    };
  }
}
```

#### 3.1.4 HTTP Interceptors for Security

##### Authentication Interceptor

```typescript
/**
 * Attaches JWT access token to outgoing API requests.
 * Handles 401 responses with silent token refresh and request retry.
 */
@Injectable()
export class AuthInterceptor implements HttpInterceptor {

  private isRefreshing = false;
  private readonly refreshTokenSubject = new BehaviorSubject<string | null>(null);

  constructor(private readonly authService: AuthService) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    // Skip auth header for public endpoints
    if (this.isPublicEndpoint(req.url)) {
      return next.handle(req);
    }

    const token = this.authService.getAccessToken();
    const authReq = token ? this.addAuthHeader(req, token) : req;

    return next.handle(authReq).pipe(
      catchError(error => {
        if (error instanceof HttpErrorResponse && error.status === 401) {
          return this.handle401Error(authReq, next);
        }
        return throwError(() => error);
      })
    );
  }

  private handle401Error(
    request: HttpRequest<unknown>,
    next: HttpHandler
  ): Observable<HttpEvent<unknown>> {
    if (!this.isRefreshing) {
      this.isRefreshing = true;
      this.refreshTokenSubject.next(null);

      return this.authService.refreshToken().pipe(
        switchMap(newToken => {
          this.isRefreshing = false;
          this.refreshTokenSubject.next(newToken);
          return next.handle(this.addAuthHeader(request, newToken));
        }),
        catchError(error => {
          this.isRefreshing = false;
          this.authService.logout();
          return throwError(() => error);
        })
      );
    }

    // Queue subsequent requests until refresh completes
    return this.refreshTokenSubject.pipe(
      filter(token => token !== null),
      take(1),
      switchMap(token => next.handle(this.addAuthHeader(request, token!)))
    );
  }

  private addAuthHeader(request: HttpRequest<unknown>, token: string): HttpRequest<unknown> {
    return request.clone({
      setHeaders: { Authorization: `Bearer ${token}` }
    });
  }

  private isPublicEndpoint(url: string): boolean {
    const publicPaths = ['/api/v1/auth/login', '/api/v1/auth/register', '/api/v1/public/'];
    return publicPaths.some(path => url.includes(path));
  }
}
```

##### Error Interceptor with Security Event Logging

```typescript
/**
 * Centralizes HTTP error handling.
 * Logs security-relevant events (401, 403) for audit trails.
 * Never exposes raw server error details to the user.
 */
@Injectable()
export class ErrorInterceptor implements HttpInterceptor {

  constructor(
    @Inject(LOGGER) private readonly logger: LoggerService,
    private readonly notificationService: NotificationService
  ) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        this.logError(req, error);
        this.showUserFriendlyMessage(error);
        return throwError(() => this.sanitizeError(error));
      })
    );
  }

  private logError(req: HttpRequest<unknown>, error: HttpErrorResponse): void {
    const context = {
      method: req.method,
      url: req.urlWithParams,
      status: error.status,
      statusText: error.statusText
    };

    switch (error.status) {
      case 401:
        this.logger.warn('SECURITY: Unauthorized access attempt', context);
        break;
      case 403:
        this.logger.warn('SECURITY: Forbidden access attempt', context);
        break;
      case 0:
        this.logger.error('Network error or CORS issue', undefined, context);
        break;
      default:
        this.logger.error('HTTP error', undefined, context);
    }
  }

  private showUserFriendlyMessage(error: HttpErrorResponse): void {
    const messages: Record<number, string> = {
      0: 'Unable to reach the server. Please check your connection.',
      400: 'The request was invalid. Please check your input.',
      401: 'Your session has expired. Please log in again.',
      403: 'You do not have permission to perform this action.',
      404: 'The requested resource was not found.',
      409: 'A conflict occurred. The resource may have been modified.',
      422: 'The submitted data could not be processed.',
      429: 'Too many requests. Please wait and try again.',
      500: 'An unexpected server error occurred. Please try again later.',
      503: 'The service is temporarily unavailable. Please try again later.'
    };

    const message = messages[error.status] ?? 'An unexpected error occurred.';
    this.notificationService.show('error', message);
  }

  /**
   * Strip sensitive server details before propagating errors.
   * Never expose stack traces, SQL errors, or internal paths to the client.
   */
  private sanitizeError(error: HttpErrorResponse): HttpErrorResponse {
    return new HttpErrorResponse({
      error: { message: 'An error occurred' },
      headers: error.headers,
      status: error.status,
      statusText: error.statusText,
      url: error.url ?? undefined
    });
  }
}
```

##### Security Headers Interceptor

```typescript
/**
 * Adds security-related headers to all outgoing requests.
 */
@Injectable()
export class SecurityHeadersInterceptor implements HttpInterceptor {

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const secureReq = req.clone({
      setHeaders: {
        'X-Content-Type-Options': 'nosniff',
        'X-Requested-With': 'XMLHttpRequest',
        'Cache-Control': 'no-store',
        'Pragma': 'no-cache'
      }
    });
    return next.handle(secureReq);
  }
}
```

##### Interceptor Registration Order

```typescript
/**
 * Interceptors execute in registration order for requests
 * and in REVERSE order for responses.
 *
 * Order matters:
 * 1. SecurityHeaders — adds base headers
 * 2. Auth — adds Authorization header
 * 3. Logging — logs complete request/response
 * 4. Error — catches and handles errors (outermost catchError)
 */
@NgModule({
  providers: [
    { provide: HTTP_INTERCEPTORS, useClass: SecurityHeadersInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: LoggingInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: ErrorInterceptor, multi: true }
  ]
})
export class CoreModule {}
```

### 3.2 Sensitive Data Handling (PCI/PII)

#### 3.2.1 Data Masking in the UI

```typescript
/**
 * Pipe to mask sensitive data in templates.
 * Use for credit card numbers, SSN, account numbers, etc.
 *
 * Usage:
 *   {{ cardNumber | mask:'card' }}     → **** **** **** 1234
 *   {{ ssn | mask:'ssn' }}             → ***-**-6789
 *   {{ email | mask:'email' }}         → j***@example.com
 *   {{ phone | mask:'phone' }}         → (***) ***-4567
 */
@Pipe({ name: 'mask' })
export class MaskPipe implements PipeTransform {

  transform(value: string | null | undefined, type: MaskType = 'default'): string {
    if (!value) return '';

    switch (type) {
      case 'card':
        return this.maskCard(value);
      case 'ssn':
        return this.maskSsn(value);
      case 'email':
        return this.maskEmail(value);
      case 'phone':
        return this.maskPhone(value);
      default:
        return this.maskDefault(value);
    }
  }

  private maskCard(value: string): string {
    const digits = value.replace(/\D/g, '');
    if (digits.length < 4) return '****';
    const last4 = digits.slice(-4);
    return `**** **** **** ${last4}`;
  }

  private maskSsn(value: string): string {
    const digits = value.replace(/\D/g, '');
    if (digits.length < 4) return '***-**-****';
    return `***-**-${digits.slice(-4)}`;
  }

  private maskEmail(value: string): string {
    const [local, domain] = value.split('@');
    if (!domain) return '***@***.***';
    const maskedLocal = local.charAt(0) + '***';
    return `${maskedLocal}@${domain}`;
  }

  private maskPhone(value: string): string {
    const digits = value.replace(/\D/g, '');
    if (digits.length < 4) return '(***) ***-****';
    return `(***) ***-${digits.slice(-4)}`;
  }

  private maskDefault(value: string): string {
    if (value.length <= 4) return '****';
    return '*'.repeat(value.length - 4) + value.slice(-4);
  }
}

type MaskType = 'card' | 'ssn' | 'email' | 'phone' | 'default';
```

#### 3.2.2 Sensitive Data Rules (NON-NEGOTIABLE)

- **Never store tokens, passwords, PII, or PCI data** in `localStorage`, `sessionStorage`, or cookies accessible to JavaScript.
- **Never log PII** (names, emails, card numbers, SSN) to the browser console in production.
- **Never include PII in URL parameters** — URLs are logged by proxies, browsers, and analytics tools.
- **Never cache API responses containing PII** in service workers or browser cache — set `Cache-Control: no-store` on sensitive endpoints.
- **Always mask PII** when displayed in the UI (use the `MaskPipe` above).
- **Always transmit sensitive data** over HTTPS only — enforce via CSP `upgrade-insecure-requests`.

```typescript
/**
 * Production console guard — prevents accidental PII logging.
 * Replaces console methods in production to strip sensitive data.
 */
export function disableConsoleInProduction(): void {
  if (environment.production) {
    const noop = (): void => {};
    console.debug = noop;
    console.log = noop;
    // Keep console.warn and console.error for critical issues
    // but route them through the structured logger instead.
  }
}

// Call in main.ts before bootstrapping
disableConsoleInProduction();
platformBrowserDynamic().bootstrapModule(AppModule);
```

#### 3.2.3 Audit Logging for PII Access

```typescript
/**
 * Directive for auditing PII field access.
 * Logs when a user views or copies sensitive data.
 *
 * Usage:
 *   <span appAuditAccess="ssn" [auditContext]="{ userId: user.id }">
 *     {{ user.ssn | mask:'ssn' }}
 *   </span>
 */
@Directive({ selector: '[appAuditAccess]' })
export class AuditAccessDirective implements OnInit {

  @Input('appAuditAccess') fieldName = '';
  @Input() auditContext: Record<string, unknown> = {};

  constructor(
    private readonly el: ElementRef,
    private readonly auditService: AuditService,
    private readonly authService: AuthService
  ) {}

  ngOnInit(): void {
    // Log when the element becomes visible (IntersectionObserver)
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.logAccess('viewed');
            observer.unobserve(this.el.nativeElement);
          }
        });
      },
      { threshold: 0.5 }
    );

    observer.observe(this.el.nativeElement);
  }

  @HostListener('copy')
  onCopy(): void {
    this.logAccess('copied');
  }

  private logAccess(action: string): void {
    this.auditService.log({
      eventName: 'pii.access',
      action,
      field: this.fieldName,
      context: this.auditContext,
      timestamp: new Date().toISOString()
    });
  }
}
```

### 3.3 Externalized Configuration

#### 3.3.1 Environment Configuration

```typescript
/**
 * Environment files define compile-time configuration.
 * Secrets MUST NOT be stored here — they are embedded in the bundle.
 */

// environment.ts (development)
export const environment = {
  production: false,
  apiBaseUrl: 'http://localhost:8080',
  authConfig: {
    issuer: 'https://dev-auth.company.com',
    clientId: 'angular-app-dev',
    redirectUri: 'http://localhost:4200/auth/callback',
    scope: 'openid profile email',
    responseType: 'code'
  },
  featureFlags: {
    enableNewDashboard: true,
    enableExport: true,
    enableBetaFeatures: true
  },
  logging: {
    level: 'debug',
    enableConsole: true
  }
};

// environment.prod.ts (production)
export const environment = {
  production: true,
  apiBaseUrl: 'https://api.company.com',
  authConfig: {
    issuer: 'https://auth.company.com',
    clientId: 'angular-app-prod',
    redirectUri: 'https://app.company.com/auth/callback',
    scope: 'openid profile email',
    responseType: 'code'
  },
  featureFlags: {
    enableNewDashboard: false,
    enableExport: true,
    enableBetaFeatures: false
  },
  logging: {
    level: 'warn',
    enableConsole: false
  }
};
```

#### 3.3.2 Runtime Configuration for Secrets and Dynamic Values

```typescript
/**
 * Runtime configuration loaded at application startup.
 * Use for values that must NOT be baked into the JavaScript bundle:
 * - API keys fetched from a backend config endpoint
 * - Feature flags from LaunchDarkly / Azure App Configuration
 * - Tenant-specific settings in multi-tenant deployments
 *
 * IMPORTANT: Even runtime config endpoints must require authentication
 * or be scoped to non-secret configuration only.
 */
export interface RuntimeConfig {
  readonly analyticsKey: string;
  readonly featureFlags: Record<string, boolean>;
  readonly supportedLocales: string[];
  readonly maintenanceMode: boolean;
}

@Injectable({ providedIn: 'root' })
export class RuntimeConfigService {

  private config: RuntimeConfig | null = null;

  constructor(private readonly http: HttpClient) {}

  /**
   * Called during APP_INITIALIZER — blocks bootstrap until config is loaded.
   */
  load(): Promise<void> {
    return this.http.get<RuntimeConfig>(
      `${environment.apiBaseUrl}/api/v1/config/client`
    ).pipe(
      tap(config => {
        this.config = Object.freeze(config);
      }),
      catchError(error => {
        console.error('Failed to load runtime configuration', error);
        // Use safe defaults — do not expose the error to the user
        this.config = Object.freeze({
          analyticsKey: '',
          featureFlags: {},
          supportedLocales: ['en-US'],
          maintenanceMode: false
        });
        return of(undefined);
      }),
      map(() => undefined)
    ).toPromise();
  }

  get<K extends keyof RuntimeConfig>(key: K): RuntimeConfig[K] {
    if (!this.config) {
      throw new Error('RuntimeConfig not initialized. Ensure APP_INITIALIZER is configured.');
    }
    return this.config[key];
  }

  isFeatureEnabled(flag: string): boolean {
    return this.config?.featureFlags[flag] ?? false;
  }
}

/**
 * APP_INITIALIZER registration — loads config before app renders.
 */
export function initializeApp(configService: RuntimeConfigService): () => Promise<void> {
  return () => configService.load();
}

@NgModule({
  providers: [
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [RuntimeConfigService],
      multi: true
    }
  ]
})
export class AppModule {}
```

### 3.4 Secure Routing

#### 3.4.1 Route Protection Checklist

| Rule | Implementation |
|------|----------------|
| All authenticated routes protected | `canActivate: [AuthGuard]` |
| Role-restricted routes enforced | `canActivate: [AuthGuard, RoleGuard]` with `data: { roles: [...] }` |
| Unsaved changes guarded | `canDeactivate: [UnsavedChangesGuard]` on form routes |
| Lazy-loaded modules protected | `canLoad: [AuthGuard]` (prevents downloading the module bundle entirely) |
| Child routes inherit protection | `canActivateChild: [AuthGuard]` on parent |
| 404 wildcard route defined | `{ path: '**', redirectTo: '/not-found' }` — never expose raw Angular errors |
| No sensitive data in URL params | Use route `data`, state, or request body instead |

#### 3.4.2 Unsaved Changes Guard

```typescript
/**
 * Prevents navigation away from a form with unsaved changes.
 */
export interface HasUnsavedChanges {
  hasUnsavedChanges(): boolean;
}

@Injectable({ providedIn: 'root' })
export class UnsavedChangesGuard implements CanDeactivate<HasUnsavedChanges> {

  canDeactivate(component: HasUnsavedChanges): Observable<boolean> | boolean {
    if (component.hasUnsavedChanges()) {
      return confirm('You have unsaved changes. Are you sure you want to leave?');
    }
    return true;
  }
}

/**
 * Usage in a form component
 */
@Component({
  selector: 'app-user-form',
  template: '...'
})
export class UserFormComponent implements HasUnsavedChanges {

  form: FormGroup;

  hasUnsavedChanges(): boolean {
    return this.form.dirty;
  }
}
```

#### 3.4.3 canLoad vs. canActivate

```typescript
/**
 * canLoad: Prevents the lazy-loaded module JS bundle from downloading at all.
 * Use for modules that unauthorized users should never access.
 *
 * canActivate: Downloads the module but blocks route activation.
 * Use for modules where the bundle is not sensitive (e.g., role within authenticated state).
 */
const routes: Routes = [
  {
    path: 'admin',
    // canLoad prevents the admin module from being downloaded
    // for non-admin users — saves bandwidth and hides code.
    canLoad: [AuthGuard, AdminCanLoadGuard],
    loadChildren: () =>
      import('./features/admin/admin.module').then(m => m.AdminModule)
  },
  {
    path: 'settings',
    // canActivate: Module is downloaded but route is blocked.
    // Acceptable when the module code itself is not sensitive.
    canActivate: [AuthGuard],
    loadChildren: () =>
      import('./features/settings/settings.module').then(m => m.SettingsModule)
  }
];
```

### 3.5 Input Validation and Sanitization

#### 3.5.1 Client-Side Validation (Defense in Depth)

Client-side validation is a **user experience feature, not a security control**. The backend **must** independently validate all input. Client validation reduces unnecessary round-trips and provides immediate feedback.

```typescript
/**
 * Centralized validators — reusable across all forms.
 * Each validator includes a matching error message.
 */
export class AppValidators {

  /** Email: RFC 5322 simplified + max length */
  static email(control: AbstractControl): ValidationErrors | null {
    if (!control.value) return null;
    const pattern = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;
    return pattern.test(control.value) ? null : { email: true };
  }

  /** No script tags or event handlers in free-text fields */
  static noScript(control: AbstractControl): ValidationErrors | null {
    if (!control.value) return null;
    const dangerous = /<script|javascript:|on\w+\s*=/i;
    return dangerous.test(control.value) ? { noScript: true } : null;
  }

  /** Alphanumeric with limited special characters (names) */
  static safeName(control: AbstractControl): ValidationErrors | null {
    if (!control.value) return null;
    const pattern = /^[a-zA-Z\s\-'\.]+$/;
    return pattern.test(control.value) ? null : { safeName: true };
  }

  /** Numeric ID — digits only */
  static numericId(control: AbstractControl): ValidationErrors | null {
    if (!control.value) return null;
    return /^\d+$/.test(control.value) ? null : { numericId: true };
  }

  /** URL: Must be HTTPS */
  static httpsUrl(control: AbstractControl): ValidationErrors | null {
    if (!control.value) return null;
    try {
      const url = new URL(control.value);
      return url.protocol === 'https:' ? null : { httpsUrl: true };
    } catch {
      return { httpsUrl: true };
    }
  }

  /** Max file size (in bytes) */
  static maxFileSize(maxBytes: number): ValidatorFn {
    return (control: AbstractControl): ValidationErrors | null => {
      const file: File = control.value;
      if (!file) return null;
      return file.size <= maxBytes ? null : {
        maxFileSize: { max: maxBytes, actual: file.size }
      };
    };
  }

  /** Allowed file types */
  static allowedFileTypes(types: string[]): ValidatorFn {
    return (control: AbstractControl): ValidationErrors | null => {
      const file: File = control.value;
      if (!file) return null;
      const extension = file.name.split('.').pop()?.toLowerCase() ?? '';
      return types.includes(extension) ? null : {
        allowedFileTypes: { allowed: types, actual: extension }
      };
    };
  }
}
```

#### 3.5.2 Centralized Validation Error Messages

```typescript
/**
 * Validation message mapping — single source of truth for all error messages.
 */
export const VALIDATION_MESSAGES: Record<string, string | ((params: any) => string)> = {
  required: 'This field is required.',
  email: 'Please enter a valid email address.',
  minlength: (params: { requiredLength: number }) =>
    `Minimum ${params.requiredLength} characters required.`,
  maxlength: (params: { requiredLength: number }) =>
    `Maximum ${params.requiredLength} characters allowed.`,
  pattern: 'The format is invalid.',
  noScript: 'Input contains disallowed characters.',
  safeName: 'Only letters, spaces, hyphens, and apostrophes are allowed.',
  numericId: 'Only numeric values are allowed.',
  httpsUrl: 'URL must use HTTPS.',
  emailTaken: 'This email is already in use.',
  maxFileSize: (params: { max: number }) =>
    `File size must not exceed ${(params.max / 1024 / 1024).toFixed(1)} MB.`,
  allowedFileTypes: (params: { allowed: string[] }) =>
    `Allowed file types: ${params.allowed.join(', ')}.`
};

/**
 * Component to display validation errors consistently.
 *
 * Usage:
 *   <app-field-error [control]="form.get('email')"></app-field-error>
 */
@Component({
  selector: 'app-field-error',
  template: `
    @if (errorMessage) {
      <mat-error>{{ errorMessage }}</mat-error>
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class FieldErrorComponent {

  @Input() control: AbstractControl | null = null;

  get errorMessage(): string | null {
    if (!this.control || !this.control.errors || !this.control.touched) {
      return null;
    }

    const firstErrorKey = Object.keys(this.control.errors)[0];
    const messageDef = VALIDATION_MESSAGES[firstErrorKey];

    if (!messageDef) return 'This field is invalid.';
    if (typeof messageDef === 'function') {
      return messageDef(this.control.errors[firstErrorKey]);
    }
    return messageDef;
  }
}
```

### 3.6 Dependency Security

#### 3.6.1 Supply Chain Security Rules (NON-NEGOTIABLE)

- Run `npm audit` on every CI build. **Fail the build** on critical or high-severity vulnerabilities.
- Use `npm audit signatures` to verify package provenance.
- Pin exact dependency versions in `package-lock.json` — always commit the lock file.
- Audit new dependencies before adding them: verify publisher reputation, download count, last publish date, and open issues.
- **Never use dependencies with known critical CVEs** in production. Patch or replace immediately.
- Configure Dependabot or Renovate for automated dependency update PRs.
- Do **not** install packages with `postinstall` scripts from untrusted publishers without review.

#### 3.6.2 Automated Audit in CI

```yaml
# Azure Pipelines / GitHub Actions step
- script: |
    npm ci --ignore-scripts
    npm audit --audit-level=high
    npx lockfile-lint --path package-lock.json --type npm --allowed-hosts npm --validate-https
  displayName: 'Security audit'
  failOnStderr: true
```

#### 3.6.3 Angular-Specific Dependency Rules

| Rule | Rationale |
|------|-----------|
| Keep Angular packages on the same major version | Mixed versions cause unpredictable runtime errors |
| Update Angular within 90 days of a new major release | Security patches are only backported to supported versions |
| Avoid unmaintained Angular community libraries | Check last npm publish date — reject if > 12 months stale |
| Prefer official Angular packages (`@angular/*`, `@ngrx/*`) over third-party alternatives | Better security review cadence and compatibility guarantees |
| Do not use `@types/*` packages with pinned vulnerable transitive dependencies | Review `@types` dependency trees before adding |

---

## 4. Performance and Resiliency

### 4.0 Required Guidelines (Normative)

Use the following standards for all production Angular applications.

#### 4.0.1 Change Detection Optimization

- Use `ChangeDetectionStrategy.OnPush` on **every** component. Default change detection is prohibited in new components.
- Use `trackBy` on every `*ngFor` / `@for` to prevent unnecessary DOM re-creation.
- Use the `async` pipe (or signal reads in templates) instead of manual subscriptions and mutable class properties for observable data.
- Avoid calling functions in templates — use `computed()` signals or pre-computed properties instead, as template functions re-execute on every change detection cycle.
- Profile change detection frequency with Angular DevTools during development. Flag components with >100 checks/second for review.

#### 4.0.2 Bundle Size and Lazy Loading

- Lazy-load all feature modules. Only `CoreModule`, `SharedModule`, and `AppModule` are eagerly loaded.
- Set bundle size budgets in `angular.json`. Initial bundle **must not exceed 500 KB** (gzipped) without architecture board approval.
- Tree-shake unused code — avoid barrel file re-exports (`index.ts`) that defeat tree-shaking.
- Use `import()` for heavy third-party libraries (charts, PDF generators, rich-text editors) to defer loading until needed.
- Analyze bundle composition with `source-map-explorer` or `webpack-bundle-analyzer` on every major release.

#### 4.0.3 Network Resilience

- Protect all outbound HTTP calls with timeout, retry (for idempotent operations), and error handling.
- Display meaningful loading states and error recovery options — never leave the user staring at a blank screen.
- Implement offline awareness: detect connectivity changes and degrade gracefully.
- Cache stable reference data (countries, currencies, feature flags) locally to reduce network dependency.
- Use HTTP `ETag` / `If-None-Match` headers for frequently polled data to reduce bandwidth.

#### 4.0.4 Memory Management

- Unsubscribe from all observables in `ngOnDestroy`. Use `takeUntilDestroyed()`, `takeUntil(destroy$)`, or the `async` pipe.
- Never store unbounded data in component state — paginate lists, cap caches, and prune old entries.
- Detach and clean up event listeners, `IntersectionObserver`, `MutationObserver`, and `ResizeObserver` references.
- Profile memory usage with Chrome DevTools heap snapshots during development. Flag components with retained DOM nodes for review.

### 4.1 Change Detection Performance

#### OnPush Change Detection (MANDATORY)

```typescript
/**
 * ✅ CORRECT: OnPush — Angular only checks this component when:
 * 1. An @Input() reference changes (immutable data flow)
 * 2. An event originates from this component or its children
 * 3. An observable bound via async pipe emits
 * 4. A signal read in the template updates
 * 5. markForCheck() or detectChanges() is explicitly called
 */
@Component({
  selector: 'app-user-card',
  template: `
    <mat-card>
      <mat-card-title>{{ user.fullName }}</mat-card-title>
      <mat-card-subtitle>{{ user.email }}</mat-card-subtitle>
      <mat-card-content>
        <span [class]="'badge badge-' + user.status.toLowerCase()">
          {{ user.status }}
        </span>
      </mat-card-content>
    </mat-card>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush  // MANDATORY
})
export class UserCardComponent {
  @Input({ required: true }) user!: User;
}

/**
 * ❌ WRONG: Default change detection — re-checks on EVERY browser event
 */
@Component({
  selector: 'app-user-card',
  template: `...`
  // Missing ChangeDetectionStrategy.OnPush — default checks every cycle
})
export class UserCardComponent {
  @Input() user!: User;
}
```

#### Avoiding Template Function Calls

```typescript
/**
 * ❌ WRONG: Function called in template — re-executes every change detection cycle
 */
@Component({
  selector: 'app-order-list',
  template: `
    <div *ngFor="let order of orders">
      <!-- BAD: getTotal() runs every CD cycle for every row -->
      <span>{{ getTotal(order) | currency }}</span>
      <!-- BAD: isOverdue() runs every CD cycle for every row -->
      <span *ngIf="isOverdue(order)" class="overdue">Overdue</span>
    </div>
  `
})
export class OrderListComponent {
  @Input() orders: Order[] = [];

  getTotal(order: Order): number {
    return order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  }

  isOverdue(order: Order): boolean {
    return new Date() > new Date(order.dueDate);
  }
}

/**
 * ✅ CORRECT: Pre-compute in the model or use a pipe
 */
@Component({
  selector: 'app-order-list',
  template: `
    <div *ngFor="let order of orders; trackBy: trackByOrderId">
      <span>{{ order.total | currency }}</span>
      <span *ngIf="order.isOverdue" class="overdue">Overdue</span>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OrderListComponent {
  @Input() orders: OrderViewModel[] = [];

  trackByOrderId(index: number, order: OrderViewModel): string {
    return order.id;
  }
}

/**
 * Map domain model to a view model with pre-computed fields
 */
export interface OrderViewModel {
  readonly id: string;
  readonly orderNumber: string;
  readonly total: number;       // Pre-computed
  readonly isOverdue: boolean;  // Pre-computed
  readonly items: OrderItem[];
}

export class OrderViewModelMapper {
  static fromDomain(order: Order): OrderViewModel {
    return {
      ...order,
      total: order.items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      isOverdue: new Date() > new Date(order.dueDate)
    };
  }
}
```

#### Pure Pipes for Template Transformations

```typescript
/**
 * ✅ CORRECT: Pure pipe — Angular caches the result and only re-evaluates
 * when the input reference changes. Far cheaper than a template function.
 */
@Pipe({ name: 'orderTotal', pure: true })
export class OrderTotalPipe implements PipeTransform {
  transform(items: OrderItem[]): number {
    return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  }
}

// Usage: {{ order.items | orderTotal | currency }}
```

### 4.2 Bundle Optimization

#### 4.2.1 Angular.json Budget Configuration

```json
{
  "projects": {
    "app": {
      "architect": {
        "build": {
          "configurations": {
            "production": {
              "budgets": [
                {
                  "type": "initial",
                  "maximumWarning": "400kb",
                  "maximumError": "500kb"
                },
                {
                  "type": "anyComponentStyle",
                  "maximumWarning": "4kb",
                  "maximumError": "8kb"
                },
                {
                  "type": "anyScript",
                  "maximumWarning": "100kb",
                  "maximumError": "150kb"
                }
              ],
              "outputHashing": "all",
              "sourceMap": false,
              "namedChunks": false,
              "optimization": true
            }
          }
        }
      }
    }
  }
}
```

#### 4.2.2 Dynamic Imports for Heavy Libraries

```typescript
/**
 * ❌ WRONG: Eagerly importing a heavy charting library
 * This adds ~500 KB to the initial bundle even if charts are rarely viewed.
 */
import { Chart } from 'chart.js';   // BAD: Loaded upfront

/**
 * ✅ CORRECT: Dynamic import — loaded only when the chart component renders.
 */
@Component({
  selector: 'app-analytics-chart',
  template: `<canvas #chartCanvas></canvas>`,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AnalyticsChartComponent implements AfterViewInit {

  @ViewChild('chartCanvas') canvasRef!: ElementRef<HTMLCanvasElement>;
  @Input({ required: true }) data!: ChartDataset[];

  async ngAfterViewInit(): Promise<void> {
    // Chart.js is only downloaded when this component renders
    const { Chart, registerables } = await import('chart.js');
    Chart.register(...registerables);

    new Chart(this.canvasRef.nativeElement, {
      type: 'bar',
      data: { labels: this.data.map(d => d.label), datasets: [{ data: this.data.map(d => d.value) }] },
      options: { responsive: true }
    });
  }
}

/**
 * ✅ CORRECT: Dynamic import for PDF export (rarely used feature)
 */
@Injectable({ providedIn: 'root' })
export class PdfExportService {

  async exportToPdf(data: ReportData): Promise<Blob> {
    const { jsPDF } = await import('jspdf');
    const doc = new jsPDF();
    doc.text(data.title, 10, 10);
    // ... build PDF
    return doc.output('blob');
  }
}
```

#### 4.2.3 Preloading Strategy

```typescript
/**
 * Custom preloading strategy — preloads modules flagged for preload
 * while deferring low-priority modules until requested.
 */
@Injectable({ providedIn: 'root' })
export class SelectivePreloadingStrategy implements PreloadingStrategy {

  preload(route: Route, load: () => Observable<any>): Observable<any> {
    // Preload if route data says so
    if (route.data?.['preload'] === true) {
      return load();
    }
    return of(null);
  }
}

const routes: Routes = [
  {
    path: 'dashboard',
    loadChildren: () => import('./features/dashboard/dashboard.module').then(m => m.DashboardModule),
    data: { preload: true }   // High priority — preload after initial render
  },
  {
    path: 'users',
    loadChildren: () => import('./features/users/users.module').then(m => m.UsersModule),
    data: { preload: true }
  },
  {
    path: 'reports',
    loadChildren: () => import('./features/reports/reports.module').then(m => m.ReportsModule),
    data: { preload: false }  // Low priority — load on demand only
  },
  {
    path: 'admin',
    loadChildren: () => import('./features/admin/admin.module').then(m => m.AdminModule),
    data: { preload: false }  // Small audience — load on demand only
  }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, {
    preloadingStrategy: SelectivePreloadingStrategy
  })]
})
export class AppRoutingModule {}
```

### 4.3 HTTP Resilience Patterns

#### 4.3.1 Timeout

```typescript
/**
 * Timeout operator — prevents hanging requests from blocking the UI.
 * Apply to every HTTP call via a reusable operator or interceptor.
 */
@Injectable({ providedIn: 'root' })
export class UserService {

  private readonly defaultTimeout = 10_000; // 10 seconds

  constructor(private readonly http: HttpClient) {}

  getUsers(): Observable<User[]> {
    return this.http.get<UserDto[]>(this.apiUrl).pipe(
      timeout(this.defaultTimeout),
      map(dtos => dtos.map(UserMapper.toDomain)),
      catchError(error => {
        if (error instanceof TimeoutError) {
          return throwError(() => new AppError(
            'Request timed out. Please check your connection and try again.',
            'TIMEOUT'
          ));
        }
        return throwError(() => error);
      })
    );
  }
}

/**
 * ✅ PREFERRED: Timeout interceptor — applies globally to all requests.
 * Individual services can override via custom headers.
 */
@Injectable()
export class TimeoutInterceptor implements HttpInterceptor {

  private readonly defaultTimeout = 15_000;

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const customTimeout = Number(req.headers.get('X-Request-Timeout'));
    const timeoutMs = customTimeout > 0 ? customTimeout : this.defaultTimeout;

    // Remove the custom header before forwarding
    const cleanReq = req.clone({
      headers: req.headers.delete('X-Request-Timeout')
    });

    return next.handle(cleanReq).pipe(
      timeout(timeoutMs)
    );
  }
}

/**
 * Calling with a custom timeout for a slow report endpoint
 */
generateReport(params: ReportParams): Observable<ReportResult> {
  const headers = new HttpHeaders().set('X-Request-Timeout', '60000'); // 60s
  return this.http.post<ReportResult>(this.reportUrl, params, { headers });
}
```

#### 4.3.2 Retry with Exponential Backoff

```typescript
/**
 * Reusable retry operator with exponential backoff and jitter.
 * Retries ONLY on transient errors (5xx, 0, 429). Never retries 4xx.
 */
export function retryWithBackoff<T>(config: RetryConfig = {}): MonoTypeOperatorFunction<T> {
  const {
    maxRetries = 3,
    initialDelay = 1000,
    maxDelay = 30_000,
    retryableStatuses = [0, 408, 429, 500, 502, 503, 504]
  } = config;

  return (source: Observable<T>) =>
    source.pipe(
      retry({
        count: maxRetries,
        delay: (error: HttpErrorResponse, retryCount: number) => {
          // Only retry transient errors
          if (!retryableStatuses.includes(error.status)) {
            return throwError(() => error);
          }

          // Exponential backoff with jitter
          const exponentialDelay = Math.min(
            initialDelay * Math.pow(2, retryCount - 1),
            maxDelay
          );
          const jitter = exponentialDelay * 0.3 * Math.random();
          const delay = exponentialDelay + jitter;

          console.warn(
            `Retry ${retryCount}/${maxRetries} after ${Math.round(delay)}ms ` +
            `for status ${error.status}`
          );

          return timer(delay);
        }
      })
    );
}

export interface RetryConfig {
  maxRetries?: number;
  initialDelay?: number;
  maxDelay?: number;
  retryableStatuses?: number[];
}

/**
 * Usage in a service
 */
@Injectable({ providedIn: 'root' })
export class OrderService {

  constructor(private readonly http: HttpClient) {}

  /**
   * GET is idempotent — safe to retry.
   */
  getOrders(): Observable<Order[]> {
    return this.http.get<OrderDto[]>(this.apiUrl).pipe(
      timeout(10_000),
      retryWithBackoff({ maxRetries: 3 }),
      map(dtos => dtos.map(OrderMapper.toDomain)),
      catchError(error => this.handleFinalError(error, 'getOrders'))
    );
  }

  /**
   * POST is NOT idempotent — do NOT retry unless the backend supports
   * idempotency keys.
   */
  createOrder(request: CreateOrderRequest): Observable<Order> {
    return this.http.post<OrderDto>(this.apiUrl, request).pipe(
      timeout(15_000),
      // NO retryWithBackoff — POST is not idempotent
      map(dto => OrderMapper.toDomain(dto)),
      catchError(error => this.handleFinalError(error, 'createOrder'))
    );
  }

  /**
   * POST with idempotency key — safe to retry because backend deduplicates.
   */
  createPayment(request: PaymentRequest): Observable<PaymentResult> {
    const idempotencyKey = crypto.randomUUID();
    const headers = new HttpHeaders().set('Idempotency-Key', idempotencyKey);

    return this.http.post<PaymentResult>(this.paymentUrl, request, { headers }).pipe(
      timeout(20_000),
      retryWithBackoff({ maxRetries: 2 }),
      catchError(error => this.handleFinalError(error, 'createPayment'))
    );
  }

  private handleFinalError(error: unknown, operation: string): Observable<never> {
    console.error(`[${operation}] Final error after all retries`, error);
    return throwError(() => error);
  }
}
```

#### 4.3.3 Circuit Breaker (Client-Side)

```typescript
/**
 * Client-side circuit breaker for HTTP calls.
 * Prevents flooding a failing backend with requests.
 *
 * States:
 * - CLOSED: Normal operation. All requests pass through.
 * - OPEN: Backend is considered down. Requests fail-fast without HTTP call.
 * - HALF_OPEN: After a wait period, a single probe request is allowed through.
 */
@Injectable({ providedIn: 'root' })
export class CircuitBreakerService {

  private readonly circuits = new Map<string, CircuitState>();

  getCircuit(name: string, config?: CircuitBreakerConfig): CircuitState {
    if (!this.circuits.has(name)) {
      this.circuits.set(name, new CircuitState(name, config));
    }
    return this.circuits.get(name)!;
  }
}

export class CircuitState {

  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failureCount = 0;
  private lastFailureTime = 0;
  private readonly failureThreshold: number;
  private readonly resetTimeoutMs: number;

  constructor(
    public readonly name: string,
    config: CircuitBreakerConfig = {}
  ) {
    this.failureThreshold = config.failureThreshold ?? 5;
    this.resetTimeoutMs = config.resetTimeoutMs ?? 30_000;
  }

  get currentState(): string {
    this.evaluateState();
    return this.state;
  }

  /**
   * Wraps an observable with circuit breaker logic.
   */
  execute<T>(request: () => Observable<T>, fallback?: () => Observable<T>): Observable<T> {
    this.evaluateState();

    if (this.state === 'OPEN') {
      console.warn(`Circuit [${this.name}] is OPEN — fail-fast`);
      if (fallback) {
        return fallback();
      }
      return throwError(() => new CircuitBreakerOpenError(this.name));
    }

    return request().pipe(
      tap(() => this.onSuccess()),
      catchError(error => {
        this.onFailure();
        if (fallback && this.state === 'OPEN') {
          return fallback();
        }
        return throwError(() => error);
      })
    );
  }

  private onSuccess(): void {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      console.error(
        `Circuit [${this.name}] OPENED after ${this.failureCount} failures`
      );
    }
  }

  private evaluateState(): void {
    if (this.state === 'OPEN') {
      const elapsed = Date.now() - this.lastFailureTime;
      if (elapsed >= this.resetTimeoutMs) {
        this.state = 'HALF_OPEN';
        console.info(`Circuit [${this.name}] moved to HALF_OPEN — probing`);
      }
    }
  }
}

export interface CircuitBreakerConfig {
  failureThreshold?: number;
  resetTimeoutMs?: number;
}

export class CircuitBreakerOpenError extends Error {
  constructor(circuitName: string) {
    super(`Circuit breaker [${circuitName}] is open. Service is temporarily unavailable.`);
    this.name = 'CircuitBreakerOpenError';
  }
}

/**
 * Usage in a service
 */
@Injectable({ providedIn: 'root' })
export class ProductService {

  private readonly circuit: CircuitState;

  constructor(
    private readonly http: HttpClient,
    private readonly circuitBreaker: CircuitBreakerService
  ) {
    this.circuit = this.circuitBreaker.getCircuit('productService', {
      failureThreshold: 5,
      resetTimeoutMs: 30_000
    });
  }

  getProducts(): Observable<Product[]> {
    return this.circuit.execute(
      // Primary request
      () => this.http.get<ProductDto[]>(this.apiUrl).pipe(
        timeout(10_000),
        retryWithBackoff({ maxRetries: 2 }),
        map(dtos => dtos.map(ProductMapper.toDomain))
      ),
      // Fallback when circuit is open
      () => this.getCachedProducts()
    );
  }

  private getCachedProducts(): Observable<Product[]> {
    const cached = localStorage.getItem('products_cache');
    if (cached) {
      console.info('Returning cached products (circuit open)');
      return of(JSON.parse(cached) as Product[]);
    }
    return throwError(() => new Error('No cached products available'));
  }
}
```

#### 4.3.4 Fallback and Graceful Degradation

```typescript
/**
 * Comprehensive fallback strategies for Angular applications.
 */
@Injectable({ providedIn: 'root' })
export class RecommendationService {

  constructor(
    private readonly http: HttpClient,
    private readonly circuitBreaker: CircuitBreakerService
  ) {}

  /**
   * Strategy 1: Cached fallback — return stale data over no data.
   */
  getRecommendations(userId: string): Observable<Product[]> {
    const cacheKey = `recommendations_${userId}`;

    return this.http.get<Product[]>(`${this.apiUrl}/recommendations/${userId}`).pipe(
      timeout(5_000),
      tap(products => {
        // Update cache on success
        sessionStorage.setItem(cacheKey, JSON.stringify(products));
      }),
      catchError(() => {
        // Fallback to cached recommendations
        const cached = sessionStorage.getItem(cacheKey);
        if (cached) {
          return of(JSON.parse(cached) as Product[]);
        }
        // Fallback to popular products
        return this.getPopularProducts();
      })
    );
  }

  /**
   * Strategy 2: Default/degraded data — return something useful.
   */
  private getPopularProducts(): Observable<Product[]> {
    return this.http.get<Product[]>(`${this.apiUrl}/products/popular`).pipe(
      timeout(5_000),
      catchError(() => of([]))  // Last resort: empty list
    );
  }

  /**
   * Strategy 3: Partial success — load what you can, skip what fails.
   */
  getDashboardData(): Observable<DashboardData> {
    return forkJoin({
      orders: this.http.get<Order[]>(`${this.apiUrl}/orders/recent`).pipe(
        timeout(5_000),
        catchError(() => of([]))  // Degrade: show dashboard without orders
      ),
      notifications: this.http.get<Notification[]>(`${this.apiUrl}/notifications`).pipe(
        timeout(5_000),
        catchError(() => of([]))  // Degrade: show dashboard without notifications
      ),
      stats: this.http.get<DashboardStats>(`${this.apiUrl}/stats`).pipe(
        timeout(5_000),
        catchError(() => of(DEFAULT_STATS))  // Degrade: show placeholder stats
      )
    });
  }
}
```

### 4.4 Caching Strategies

#### 4.4.1 HTTP Cache Interceptor

```typescript
/**
 * In-memory HTTP cache interceptor for GET requests.
 * Caches responses by URL with configurable TTL.
 * Bypasses cache for mutating requests and when a custom header is set.
 */
@Injectable()
export class CacheInterceptor implements HttpInterceptor {

  private readonly cache = new Map<string, CacheEntry>();
  private readonly defaultTtl = 5 * 60 * 1000; // 5 minutes

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    // Only cache GET requests
    if (req.method !== 'GET') {
      this.invalidateRelated(req.url);
      return next.handle(req);
    }

    // Skip cache if explicitly requested
    if (req.headers.has('X-Skip-Cache')) {
      const cleanReq = req.clone({ headers: req.headers.delete('X-Skip-Cache') });
      return next.handle(cleanReq);
    }

    // Check cache
    const cacheKey = req.urlWithParams;
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiry > Date.now()) {
      return of(cached.response.clone());
    }

    // Fetch and cache
    return next.handle(req).pipe(
      tap(event => {
        if (event instanceof HttpResponse) {
          const ttl = this.getTtl(req);
          this.cache.set(cacheKey, {
            response: event.clone(),
            expiry: Date.now() + ttl
          });
        }
      })
    );
  }

  private getTtl(req: HttpRequest<unknown>): number {
    const customTtl = Number(req.headers.get('X-Cache-TTL'));
    return customTtl > 0 ? customTtl : this.defaultTtl;
  }

  private invalidateRelated(url: string): void {
    // Invalidate all cached entries under the same base path
    const basePath = url.split('?')[0];
    this.cache.forEach((_, key) => {
      if (key.startsWith(basePath)) {
        this.cache.delete(key);
      }
    });
  }
}

interface CacheEntry {
  response: HttpResponse<unknown>;
  expiry: number;
}
```

#### 4.4.2 Service-Level Cache with Stale-While-Revalidate

```typescript
/**
 * Stale-while-revalidate pattern:
 * Return cached data immediately, then refresh in the background.
 * Ideal for data that changes infrequently (reference data, user profiles).
 */
@Injectable({ providedIn: 'root' })
export class CountryService {

  private cache$: Observable<Country[]> | null = null;
  private readonly refreshInterval = 60 * 60 * 1000; // 1 hour

  constructor(private readonly http: HttpClient) {}

  getCountries(): Observable<Country[]> {
    if (!this.cache$) {
      this.cache$ = this.http.get<Country[]>(`${this.apiUrl}/countries`).pipe(
        // Cache the latest emission and replay to all subscribers
        shareReplay({ bufferSize: 1, refCount: false }),
        // Auto-refresh after the interval
        tap(() => {
          setTimeout(() => { this.cache$ = null; }, this.refreshInterval);
        })
      );
    }
    return this.cache$;
  }

  /**
   * Force refresh (e.g., after a locale change)
   */
  invalidateCache(): void {
    this.cache$ = null;
  }
}
```

### 4.5 Rendering Performance

#### 4.5.1 Virtual Scrolling for Large Lists

```typescript
/**
 * Use CDK Virtual Scrolling for lists exceeding 100 items.
 * Only renders items visible in the viewport — O(viewport) instead of O(n).
 */
@Component({
  selector: 'app-large-user-list',
  template: `
    <cdk-virtual-scroll-viewport itemSize="56" class="user-viewport">
      <div *cdkVirtualFor="let user of users; trackBy: trackByUserId"
           class="user-row">
        <span>{{ user.fullName }}</span>
        <span>{{ user.email }}</span>
        <span>{{ user.status }}</span>
      </div>
    </cdk-virtual-scroll-viewport>
  `,
  styles: [`
    .user-viewport {
      height: 600px;
      width: 100%;
    }
    .user-row {
      display: flex;
      align-items: center;
      height: 56px;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class LargeUserListComponent {
  @Input() users: User[] = [];

  trackByUserId(index: number, user: User): string {
    return user.id;
  }
}
```

#### 4.5.2 Defer Loading (Angular 17+ @defer)

```typescript
/**
 * @defer blocks load components lazily based on triggers.
 * Use for below-the-fold content, heavy components, or conditional UI.
 */
@Component({
  selector: 'app-dashboard',
  template: `
    <!-- Loads immediately — critical above-the-fold content -->
    <app-dashboard-summary [stats]="stats$ | async" />

    <!-- Loads when viewport reaches this section -->
    @defer (on viewport) {
      <app-analytics-chart [data]="chartData$ | async" />
    } @placeholder {
      <div class="chart-placeholder">Loading chart...</div>
    } @loading (minimum 300ms) {
      <app-loading-spinner />
    } @error {
      <app-error-message message="Failed to load chart" />
    }

    <!-- Loads only when the user clicks the tab -->
    @defer (on interaction(activityTab)) {
      <app-activity-feed [userId]="currentUserId" />
    } @placeholder {
      <button #activityTab mat-tab>Activity</button>
    }

    <!-- Loads after 3 seconds (low priority, non-critical) -->
    @defer (on timer(3000)) {
      <app-recommendations [userId]="currentUserId" />
    } @placeholder {
      <div class="recommendations-placeholder">
        Personalized recommendations loading...
      </div>
    }

    <!-- Loads when the browser is idle -->
    @defer (on idle) {
      <app-footer-widgets />
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class DashboardComponent {
  stats$: Observable<DashboardStats>;
  chartData$: Observable<ChartDataset[]>;
  currentUserId: string;
}
```

#### 4.5.3 Image Optimization

```typescript
/**
 * Use NgOptimizedImage for automatic image optimization.
 * Handles lazy loading, correct sizing, srcset, and LCP prioritization.
 */
@Component({
  selector: 'app-product-card',
  template: `
    <!-- Above-the-fold hero image — loaded eagerly with LCP priority -->
    <img [ngSrc]="product.heroImageUrl"
         width="800"
         height="400"
         priority
         alt="{{ product.name }}" />

    <!-- Below-the-fold thumbnail — lazy loaded automatically -->
    <img [ngSrc]="product.thumbnailUrl"
         width="200"
         height="200"
         alt="{{ product.name }} thumbnail" />
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductCardComponent {
  @Input({ required: true }) product!: Product;
}
```

### 4.6 Memory Leak Prevention

#### 4.6.1 Subscription Management

```typescript
/**
 * ✅ CORRECT: takeUntilDestroyed() — Angular 16+ (simplest approach)
 */
@Component({
  selector: 'app-notifications',
  template: `...`,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class NotificationsComponent {

  private readonly destroyRef = inject(DestroyRef);

  constructor(private readonly notificationBus: NotificationBus) {
    this.notificationBus.notifications$.pipe(
      takeUntilDestroyed(this.destroyRef)
    ).subscribe(notification => {
      this.handleNotification(notification);
    });
  }

  private handleNotification(notification: AppNotification): void {
    // Handle notification
  }
}

/**
 * ✅ CORRECT: takeUntil(destroy$) — works with all Angular versions
 */
@Component({
  selector: 'app-dashboard',
  template: `...`,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class DashboardComponent implements OnInit, OnDestroy {

  private readonly destroy$ = new Subject<void>();

  constructor(
    private readonly store: Store,
    private readonly route: ActivatedRoute
  ) {}

  ngOnInit(): void {
    // All subscriptions auto-complete when destroy$ emits
    this.store.select(selectDashboardData).pipe(
      takeUntil(this.destroy$)
    ).subscribe(data => { /* ... */ });

    this.route.params.pipe(
      takeUntil(this.destroy$)
    ).subscribe(params => { /* ... */ });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

/**
 * ✅ CORRECT: async pipe — automatically subscribes and unsubscribes
 */
@Component({
  selector: 'app-user-list',
  template: `
    <div *ngFor="let user of users$ | async; trackBy: trackByUserId">
      {{ user.fullName }}
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListComponent {
  users$ = this.store.select(selectAllUsers);
  constructor(private readonly store: Store) {}
  trackByUserId(index: number, user: User): string { return user.id; }
}

/**
 * ❌ WRONG: Manual subscribe without cleanup
 */
@Component({ selector: 'app-bad', template: '...' })
export class BadComponent implements OnInit {
  ngOnInit(): void {
    // BAD: Never unsubscribed — leaks memory when component is destroyed
    this.store.select(selectData).subscribe(data => {
      this.data = data;
    });
  }
}
```

#### 4.6.2 Event Listener and Observer Cleanup

```typescript
/**
 * Clean up browser APIs that Angular does not manage.
 */
@Component({
  selector: 'app-scroll-tracker',
  template: `...`,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ScrollTrackerComponent implements OnInit, OnDestroy {

  private resizeObserver: ResizeObserver | null = null;
  private intersectionObserver: IntersectionObserver | null = null;

  @ViewChild('target') targetRef!: ElementRef;

  ngOnInit(): void {
    // ResizeObserver
    this.resizeObserver = new ResizeObserver(entries => {
      entries.forEach(entry => {
        // Handle resize
      });
    });

    // IntersectionObserver
    this.intersectionObserver = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Handle element becoming visible
        }
      });
    });
  }

  ngAfterViewInit(): void {
    if (this.targetRef) {
      this.resizeObserver?.observe(this.targetRef.nativeElement);
      this.intersectionObserver?.observe(this.targetRef.nativeElement);
    }
  }

  ngOnDestroy(): void {
    // MANDATORY: Disconnect observers to prevent memory leaks
    this.resizeObserver?.disconnect();
    this.resizeObserver = null;
    this.intersectionObserver?.disconnect();
    this.intersectionObserver = null;
  }
}
```

### 4.7 Offline Awareness

```typescript
/**
 * Connectivity service — detects online/offline transitions.
 * Components react to connectivity changes for graceful degradation.
 */
@Injectable({ providedIn: 'root' })
export class ConnectivityService {

  private readonly onlineSubject = new BehaviorSubject<boolean>(navigator.onLine);
  readonly isOnline$ = this.onlineSubject.asObservable().pipe(distinctUntilChanged());

  constructor() {
    fromEvent(window, 'online').subscribe(() => this.onlineSubject.next(true));
    fromEvent(window, 'offline').subscribe(() => this.onlineSubject.next(false));
  }

  get isOnline(): boolean {
    return this.onlineSubject.value;
  }
}

/**
 * Offline banner component — shows a persistent banner when connectivity is lost.
 */
@Component({
  selector: 'app-offline-banner',
  template: `
    @if ((isOnline$ | async) === false) {
      <div class="offline-banner" role="alert">
        <mat-icon>cloud_off</mat-icon>
        <span>You are offline. Some features may be unavailable.</span>
      </div>
    }
  `,
  styles: [`
    .offline-banner {
      background: #f44336;
      color: white;
      padding: 8px 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      position: sticky;
      top: 0;
      z-index: 1000;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OfflineBannerComponent {
  isOnline$ = inject(ConnectivityService).isOnline$;
}
```

---

## 5. Monitoring & Logging

### 5.0 Required Guidelines (Normative)

Use the following standards for all production Angular applications.

#### 5.0.1 Structured Logging

- All log output **must** use a centralized `LoggerService` — direct `console.log` / `console.error` calls are prohibited in production code.
- Log entries **must** be structured JSON objects containing at minimum: `timestamp`, `level`, `message`, `correlationId`, and `context`.
- Sensitive data (PII, credentials, tokens, payment details) **must never** appear in log output. Sanitize before logging.
- Every HTTP request **must** carry a correlation ID propagated through headers and included in all related log entries.

#### 5.0.2 Error Tracking

- All unhandled exceptions **must** be captured by a global `ErrorHandler` and forwarded to the centralized logging pipeline.
- HTTP errors **must** be intercepted, classified by severity, and logged with request context (URL, method, status code, correlation ID).
- Client-side errors **must** include the Angular component tree path, browser metadata, and application version.

#### 5.0.3 Performance Monitoring

- Core Web Vitals (LCP, FID/INP, CLS) **must** be measured and reported for all user-facing pages.
- Route navigation timing **must** be tracked end-to-end (navigation start → component rendered).
- API call durations **must** be measured and reported via the HTTP interceptor pipeline.

#### 5.0.4 Audit Trails

- All critical operations (bookings, payments, flight changes, user role modifications) **must** produce immutable audit log entries.
- Audit entries **must** include: `userId`, `action`, `resource`, `timestamp`, `previousValue`, `newValue`, and `correlationId`.
- Audit logs **must** be forwarded to a tamper-evident backend store — client-side storage alone is insufficient.

### 5.1 Centralized Logger Service

#### 5.1.1 Log Levels and Structured Output

```typescript
/**
 * Log levels ordered by severity.
 * Production environments should use WARN or above.
 * Development and staging may use DEBUG or TRACE.
 */
export enum LogLevel {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  FATAL = 5
}

/**
 * Structured log entry — all log output conforms to this shape.
 * Enables consistent parsing by log aggregation tools (Splunk, ELK, Datadog).
 */
export interface LogEntry {
  readonly timestamp: string;
  readonly level: LogLevel;
  readonly levelName: string;
  readonly message: string;
  readonly correlationId: string;
  readonly context: string;
  readonly appVersion: string;
  readonly environment: string;
  readonly userId?: string;
  readonly sessionId?: string;
  readonly data?: Record<string, unknown>;
  readonly error?: {
    readonly name: string;
    readonly message: string;
    readonly stack?: string;
  };
}

/**
 * Logger configuration — loaded from environment files.
 */
export interface LoggerConfig {
  readonly minLevel: LogLevel;
  readonly enableConsole: boolean;
  readonly enableRemote: boolean;
  readonly remoteEndpoint: string;
  readonly batchSize: number;
  readonly flushIntervalMs: number;
  readonly sanitizeFields: string[];
}

export const DEFAULT_LOGGER_CONFIG: LoggerConfig = {
  minLevel: LogLevel.WARN,
  enableConsole: false,
  enableRemote: true,
  remoteEndpoint: '/api/v1/logs',
  batchSize: 25,
  flushIntervalMs: 5000,
  sanitizeFields: [
    'password', 'token', 'authorization', 'creditCard',
    'ssn', 'secret', 'apiKey', 'accessToken', 'refreshToken'
  ]
};
```

#### 5.1.2 Logger Service Implementation

```typescript
/**
 * Centralized logging service.
 * - Enforces structured JSON output
 * - Batches log entries for efficient remote transport
 * - Sanitizes sensitive fields before output
 * - Attaches correlation ID, user context, and app metadata automatically
 */
@Injectable({ providedIn: 'root' })
export class LoggerService implements OnDestroy {

  private readonly config: LoggerConfig;
  private readonly buffer: LogEntry[] = [];
  private flushTimer: ReturnType<typeof setInterval> | null = null;

  private readonly levelNames: Record<LogLevel, string> = {
    [LogLevel.TRACE]: 'TRACE',
    [LogLevel.DEBUG]: 'DEBUG',
    [LogLevel.INFO]: 'INFO',
    [LogLevel.WARN]: 'WARN',
    [LogLevel.ERROR]: 'ERROR',
    [LogLevel.FATAL]: 'FATAL'
  };

  constructor(
    private readonly http: HttpClient,
    private readonly correlationService: CorrelationIdService,
    private readonly authContext: AuthContextService,
    @Inject(LOGGER_CONFIG) config: Partial<LoggerConfig>
  ) {
    this.config = { ...DEFAULT_LOGGER_CONFIG, ...config };
    this.startFlushTimer();
  }

  trace(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.TRACE, message, data);
  }

  debug(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.DEBUG, message, data);
  }

  info(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.INFO, message, data);
  }

  warn(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.WARN, message, data);
  }

  error(message: string, error?: Error, data?: Record<string, unknown>): void {
    this.log(LogLevel.ERROR, message, data, error);
  }

  fatal(message: string, error?: Error, data?: Record<string, unknown>): void {
    this.log(LogLevel.FATAL, message, data, error);
    this.flush(); // Fatal errors flush immediately
  }

  private log(
    level: LogLevel,
    message: string,
    data?: Record<string, unknown>,
    error?: Error
  ): void {
    if (level < this.config.minLevel) {
      return;
    }

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      levelName: this.levelNames[level],
      message,
      correlationId: this.correlationService.getCurrentId(),
      context: this.resolveContext(),
      appVersion: environment.appVersion,
      environment: environment.name,
      userId: this.authContext.getUserId() ?? undefined,
      sessionId: this.authContext.getSessionId() ?? undefined,
      data: data ? this.sanitize(data) : undefined,
      error: error ? {
        name: error.name,
        message: error.message,
        stack: environment.production ? undefined : error.stack
      } : undefined
    };

    if (this.config.enableConsole && !environment.production) {
      this.writeToConsole(entry);
    }

    if (this.config.enableRemote) {
      this.buffer.push(entry);
      if (this.buffer.length >= this.config.batchSize) {
        this.flush();
      }
    }
  }

  private writeToConsole(entry: LogEntry): void {
    const consoleFn = entry.level >= LogLevel.ERROR ? console.error
      : entry.level >= LogLevel.WARN ? console.warn
      : console.log;
    consoleFn(`[${entry.levelName}] ${entry.message}`, entry);
  }

  /**
   * Sanitizes sensitive fields from log data.
   * Prevents PII and credentials from leaking into logs.
   */
  private sanitize(data: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(data)) {
      if (this.config.sanitizeFields.some(f => key.toLowerCase().includes(f.toLowerCase()))) {
        sanitized[key] = '[REDACTED]';
      } else if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        sanitized[key] = this.sanitize(value as Record<string, unknown>);
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  private resolveContext(): string {
    // Returns a breadcrumb of the current route or component context
    return window.location.pathname;
  }

  /**
   * Flushes buffered log entries to the remote endpoint.
   * Uses navigator.sendBeacon for page-unload scenarios.
   */
  flush(): void {
    if (this.buffer.length === 0) {
      return;
    }

    const entries = this.buffer.splice(0, this.buffer.length);
    const payload = JSON.stringify(entries);

    // Use sendBeacon for reliability during page navigation/unload
    if (typeof navigator.sendBeacon === 'function') {
      const blob = new Blob([payload], { type: 'application/json' });
      const sent = navigator.sendBeacon(this.config.remoteEndpoint, blob);
      if (!sent) {
        this.sendViaHttp(entries);
      }
    } else {
      this.sendViaHttp(entries);
    }
  }

  private sendViaHttp(entries: LogEntry[]): void {
    this.http.post(this.config.remoteEndpoint, entries, {
      headers: { 'Content-Type': 'application/json' }
    }).pipe(
      catchError(() => EMPTY) // Logging failures must not cascade
    ).subscribe();
  }

  private startFlushTimer(): void {
    if (this.config.flushIntervalMs > 0) {
      this.flushTimer = setInterval(() => this.flush(), this.config.flushIntervalMs);
    }
  }

  ngOnDestroy(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
    }
    this.flush();
  }
}

/**
 * Injection token for logger configuration.
 * Provided in CoreModule from environment-specific settings.
 */
export const LOGGER_CONFIG = new InjectionToken<Partial<LoggerConfig>>('LoggerConfig');
```

#### 5.1.3 Logger Configuration by Environment

```typescript
/**
 * environment.ts — Development
 */
export const environment = {
  production: false,
  name: 'development',
  appVersion: '1.0.0-dev',
  loggerConfig: {
    minLevel: LogLevel.DEBUG,
    enableConsole: true,
    enableRemote: false,
    remoteEndpoint: '/api/v1/logs',
    batchSize: 10,
    flushIntervalMs: 10000
  } as Partial<LoggerConfig>
};

/**
 * environment.staging.ts — Staging
 */
export const environment = {
  production: false,
  name: 'staging',
  appVersion: '1.0.0-rc.1',
  loggerConfig: {
    minLevel: LogLevel.INFO,
    enableConsole: false,
    enableRemote: true,
    remoteEndpoint: '/api/v1/logs',
    batchSize: 25,
    flushIntervalMs: 5000
  } as Partial<LoggerConfig>
};

/**
 * environment.prod.ts — Production
 */
export const environment = {
  production: true,
  name: 'production',
  appVersion: '1.0.0',
  loggerConfig: {
    minLevel: LogLevel.WARN,
    enableConsole: false,
    enableRemote: true,
    remoteEndpoint: '/api/v1/logs',
    batchSize: 50,
    flushIntervalMs: 3000
  } as Partial<LoggerConfig>
};

/**
 * CoreModule — provides logger configuration from the active environment.
 */
@NgModule({
  providers: [
    { provide: LOGGER_CONFIG, useValue: environment.loggerConfig }
  ]
})
export class CoreModule {}
```

### 5.2 Correlation ID Tracking

```typescript
/**
 * Generates and manages a correlation ID per user session.
 * The correlation ID is attached to every log entry and outbound HTTP request,
 * enabling end-to-end request tracing across frontend and backend services.
 */
@Injectable({ providedIn: 'root' })
export class CorrelationIdService {

  private correlationId: string;

  constructor() {
    this.correlationId = this.generate();
  }

  getCurrentId(): string {
    return this.correlationId;
  }

  /**
   * Rotates the correlation ID.
   * Call on authentication state changes (login/logout) for session isolation.
   */
  rotate(): void {
    this.correlationId = this.generate();
  }

  private generate(): string {
    return crypto.randomUUID();
  }
}

/**
 * HTTP interceptor that attaches the correlation ID header to every outbound request.
 * Backend services use this header to correlate frontend actions with server-side logs.
 */
@Injectable()
export class CorrelationIdInterceptor implements HttpInterceptor {

  constructor(private readonly correlationService: CorrelationIdService) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const correlatedReq = req.clone({
      setHeaders: {
        'X-Correlation-ID': this.correlationService.getCurrentId()
      }
    });
    return next.handle(correlatedReq);
  }
}
```

### 5.3 Global Error Handling

#### 5.3.1 Custom ErrorHandler

```typescript
/**
 * Global error handler — replaces Angular's default ErrorHandler.
 * Captures all unhandled exceptions and routes them to the logging pipeline.
 * Prevents silent failures in production.
 */
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {

  constructor(
    private readonly logger: LoggerService,
    private readonly ngZone: NgZone
  ) {}

  handleError(error: unknown): void {
    const resolvedError = this.unwrapError(error);

    this.ngZone.run(() => {
      this.logger.error(
        `Unhandled error: ${resolvedError.message}`,
        resolvedError,
        {
          component: this.extractComponentName(resolvedError),
          url: window.location.href,
          userAgent: navigator.userAgent,
          timestamp: Date.now()
        }
      );
    });

    // Re-throw in development for stack trace visibility in DevTools
    if (!environment.production) {
      console.error('Unhandled error caught by GlobalErrorHandler:', resolvedError);
    }
  }

  /**
   * Angular wraps errors in various wrapper types.
   * Unwrap to get the original error for accurate logging.
   */
  private unwrapError(error: unknown): Error {
    if (error instanceof Error) {
      return error;
    }
    if (typeof error === 'string') {
      return new Error(error);
    }
    return new Error('Unknown error: ' + JSON.stringify(error));
  }

  /**
   * Attempts to extract the originating component name from the error stack.
   */
  private extractComponentName(error: Error): string {
    const match = error.stack?.match(/at (\w+Component)/);
    return match ? match[1] : 'unknown';
  }
}

/**
 * Register in CoreModule — replaces Angular's default error handler globally.
 */
@NgModule({
  providers: [
    { provide: ErrorHandler, useClass: GlobalErrorHandler }
  ]
})
export class CoreModule {}
```

#### 5.3.2 HTTP Error Interceptor with Logging

```typescript
/**
 * HTTP error interceptor — classifies, logs, and optionally retries failed requests.
 * Integrates with the centralized logger and correlation ID pipeline.
 */
@Injectable()
export class HttpErrorInterceptor implements HttpInterceptor {

  constructor(
    private readonly logger: LoggerService,
    private readonly notificationService: NotificationService
  ) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const startTime = Date.now();

    return next.handle(req).pipe(
      tap({
        next: (event) => {
          if (event instanceof HttpResponse) {
            this.logSuccess(req, event, startTime);
          }
        }
      }),
      catchError((error: HttpErrorResponse) => {
        this.logHttpError(req, error, startTime);
        this.notifyUser(error);
        return throwError(() => error);
      })
    );
  }

  private logSuccess(req: HttpRequest<unknown>, res: HttpResponse<unknown>, startTime: number): void {
    const duration = Date.now() - startTime;

    this.logger.debug('HTTP request completed', {
      method: req.method,
      url: req.urlWithParams,
      status: res.status,
      durationMs: duration
    });

    // Warn on slow requests exceeding 3 seconds
    if (duration > 3000) {
      this.logger.warn('Slow HTTP request detected', {
        method: req.method,
        url: req.urlWithParams,
        status: res.status,
        durationMs: duration
      });
    }
  }

  private logHttpError(req: HttpRequest<unknown>, error: HttpErrorResponse, startTime: number): void {
    const duration = Date.now() - startTime;
    const severity = this.classifySeverity(error.status);

    const logData = {
      method: req.method,
      url: req.urlWithParams,
      status: error.status,
      statusText: error.statusText,
      durationMs: duration,
      errorBody: this.safeStringify(error.error)
    };

    switch (severity) {
      case 'warn':
        this.logger.warn(`HTTP ${error.status}: ${req.method} ${req.urlWithParams}`, logData);
        break;
      case 'error':
        this.logger.error(
          `HTTP ${error.status}: ${req.method} ${req.urlWithParams}`,
          new Error(`HTTP Error ${error.status}`),
          logData
        );
        break;
      case 'fatal':
        this.logger.fatal(
          `HTTP ${error.status}: ${req.method} ${req.urlWithParams}`,
          new Error(`HTTP Fatal Error ${error.status}`),
          logData
        );
        break;
    }
  }

  /**
   * Classifies HTTP errors by severity:
   * - 4xx client errors (except 401/403) → WARN (likely user/input issues)
   * - 401/403 → ERROR (authentication/authorization failures — security event)
   * - 5xx server errors → ERROR
   * - 0 (network failure) → FATAL
   */
  private classifySeverity(status: number): 'warn' | 'error' | 'fatal' {
    if (status === 0) return 'fatal';
    if (status === 401 || status === 403) return 'error';
    if (status >= 400 && status < 500) return 'warn';
    return 'error';
  }

  private notifyUser(error: HttpErrorResponse): void {
    if (error.status === 0) {
      this.notificationService.showError('Network error. Please check your connection.');
    } else if (error.status === 401) {
      this.notificationService.showWarning('Session expired. Please log in again.');
    } else if (error.status === 403) {
      this.notificationService.showWarning('You do not have permission to perform this action.');
    } else if (error.status >= 500) {
      this.notificationService.showError('A server error occurred. Please try again later.');
    }
  }

  private safeStringify(value: unknown): string {
    try {
      return typeof value === 'string' ? value : JSON.stringify(value);
    } catch {
      return '[non-serializable error body]';
    }
  }
}
```

#### 5.3.3 Interceptor Registration Order

```typescript
/**
 * HTTP interceptor registration — order matters.
 * Interceptors execute in order for requests, reverse order for responses.
 *
 * Request flow:  CorrelationId → Auth → Logging/Error
 * Response flow: Logging/Error → Auth → CorrelationId
 */
@NgModule({
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: CorrelationIdInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: HttpErrorInterceptor,
      multi: true
    }
  ]
})
export class CoreModule {}
```

### 5.4 Performance Monitoring

#### 5.4.1 Core Web Vitals

```typescript
/**
 * Core Web Vitals monitoring service.
 * Measures LCP, FID/INP, CLS, FCP, and TTFB using the web-vitals library.
 * Reports metrics to the logging pipeline for dashboard aggregation.
 */
@Injectable({ providedIn: 'root' })
export class WebVitalsService {

  constructor(private readonly logger: LoggerService) {}

  /**
   * Initializes Core Web Vitals observation.
   * Call once from AppComponent.ngOnInit() or APP_INITIALIZER.
   */
  async init(): Promise<void> {
    try {
      const { onLCP, onFID, onCLS, onFCP, onTTFB, onINP } = await import('web-vitals');

      onLCP(metric => this.reportMetric(metric));
      onFID(metric => this.reportMetric(metric));
      onINP(metric => this.reportMetric(metric));
      onCLS(metric => this.reportMetric(metric));
      onFCP(metric => this.reportMetric(metric));
      onTTFB(metric => this.reportMetric(metric));
    } catch (error) {
      this.logger.warn('Failed to initialize web-vitals', { error: String(error) });
    }
  }

  private reportMetric(metric: { name: string; value: number; id: string; rating: string }): void {
    const logData = {
      metricName: metric.name,
      metricValue: metric.value,
      metricId: metric.id,
      rating: metric.rating,
      url: window.location.pathname,
      navigationType: this.getNavigationType()
    };

    // Log poor-rated metrics as warnings for alerting
    if (metric.rating === 'poor') {
      this.logger.warn(`Poor Core Web Vital: ${metric.name} = ${metric.value}`, logData);
    } else {
      this.logger.info(`Web Vital: ${metric.name} = ${metric.value}`, logData);
    }
  }

  private getNavigationType(): string {
    const navEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    return navEntry?.type ?? 'unknown';
  }
}

/**
 * Initialize web vitals in APP_INITIALIZER for early measurement.
 */
export function initWebVitals(webVitals: WebVitalsService): () => Promise<void> {
  return () => webVitals.init();
}

@NgModule({
  providers: [
    {
      provide: APP_INITIALIZER,
      useFactory: initWebVitals,
      deps: [WebVitalsService],
      multi: true
    }
  ]
})
export class CoreModule {}
```

#### 5.4.2 Route Navigation Timing

```typescript
/**
 * Tracks route navigation performance.
 * Measures the time from navigation start to component render completion.
 * Identifies slow routes that degrade user experience.
 */
@Injectable({ providedIn: 'root' })
export class RoutePerformanceService implements OnDestroy {

  private readonly destroy$ = new Subject<void>();
  private navigationStart = 0;

  constructor(
    private readonly router: Router,
    private readonly logger: LoggerService
  ) {
    this.trackNavigations();
  }

  private trackNavigations(): void {
    this.router.events.pipe(
      takeUntil(this.destroy$)
    ).subscribe(event => {
      if (event instanceof NavigationStart) {
        this.navigationStart = performance.now();
      }

      if (event instanceof NavigationEnd) {
        const duration = performance.now() - this.navigationStart;
        const logData = {
          route: event.urlAfterRedirects,
          durationMs: Math.round(duration),
          navigationId: event.id
        };

        if (duration > 2000) {
          this.logger.warn('Slow route navigation detected', logData);
        } else {
          this.logger.debug('Route navigation completed', logData);
        }
      }

      if (event instanceof NavigationError) {
        this.logger.error(
          'Route navigation error',
          event.error instanceof Error ? event.error : new Error(String(event.error)),
          {
            route: event.url,
            durationMs: Math.round(performance.now() - this.navigationStart)
          }
        );
      }
    });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

#### 5.4.3 Long Task Detection

```typescript
/**
 * Detects and logs long tasks (>50ms) that block the main thread.
 * Long tasks cause input delay and contribute to poor INP scores.
 */
@Injectable({ providedIn: 'root' })
export class LongTaskMonitorService implements OnDestroy {

  private observer: PerformanceObserver | null = null;

  constructor(private readonly logger: LoggerService) {}

  /**
   * Starts observing long tasks.
   * Call once during application bootstrap.
   */
  start(): void {
    if (typeof PerformanceObserver === 'undefined') {
      return;
    }

    try {
      this.observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.duration > 100) {
            this.logger.warn('Long task detected', {
              durationMs: Math.round(entry.duration),
              startTime: Math.round(entry.startTime),
              url: window.location.pathname,
              entryType: entry.entryType
            });
          }
        }
      });

      this.observer.observe({ entryTypes: ['longtask'] });
    } catch {
      // PerformanceObserver 'longtask' not supported in all browsers
    }
  }

  ngOnDestroy(): void {
    this.observer?.disconnect();
    this.observer = null;
  }
}
```

### 5.5 Audit Trail Logging

```typescript
/**
 * Audit log entry — immutable record of a critical business operation.
 * Complies with ISO 27001 and SOC 2 audit trail requirements.
 */
export interface AuditEntry {
  readonly action: AuditAction;
  readonly resource: string;
  readonly resourceId: string;
  readonly userId: string;
  readonly correlationId: string;
  readonly timestamp: string;
  readonly previousValue?: unknown;
  readonly newValue?: unknown;
  readonly metadata?: Record<string, unknown>;
}

export enum AuditAction {
  CREATE = 'CREATE',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE',
  VIEW = 'VIEW',
  EXPORT = 'EXPORT',
  LOGIN = 'LOGIN',
  LOGOUT = 'LOGOUT',
  ROLE_CHANGE = 'ROLE_CHANGE',
  PERMISSION_GRANT = 'PERMISSION_GRANT',
  PERMISSION_REVOKE = 'PERMISSION_REVOKE',
  BOOKING_CREATE = 'BOOKING_CREATE',
  BOOKING_MODIFY = 'BOOKING_MODIFY',
  BOOKING_CANCEL = 'BOOKING_CANCEL',
  PAYMENT_INITIATE = 'PAYMENT_INITIATE',
  PAYMENT_COMPLETE = 'PAYMENT_COMPLETE',
  FLIGHT_CHANGE = 'FLIGHT_CHANGE'
}

/**
 * Audit service — records critical operations and forwards them to the backend.
 * Entries are buffered and flushed to prevent data loss.
 */
@Injectable({ providedIn: 'root' })
export class AuditService {

  private readonly auditEndpoint = `${environment.apiBaseUrl}/api/v1/audit`;

  constructor(
    private readonly http: HttpClient,
    private readonly correlationService: CorrelationIdService,
    private readonly authContext: AuthContextService,
    private readonly logger: LoggerService
  ) {}

  /**
   * Records an audit event and sends it to the backend.
   * Backend is the system of record — client-side storage is supplementary only.
   */
  record(
    action: AuditAction,
    resource: string,
    resourceId: string,
    options?: {
      previousValue?: unknown;
      newValue?: unknown;
      metadata?: Record<string, unknown>;
    }
  ): void {
    const entry: AuditEntry = {
      action,
      resource,
      resourceId,
      userId: this.authContext.getUserId() ?? 'anonymous',
      correlationId: this.correlationService.getCurrentId(),
      timestamp: new Date().toISOString(),
      previousValue: options?.previousValue,
      newValue: options?.newValue,
      metadata: options?.metadata
    };

    this.http.post(this.auditEndpoint, entry).pipe(
      catchError(error => {
        this.logger.error('Failed to record audit entry', error as Error, {
          action: entry.action,
          resource: entry.resource,
          resourceId: entry.resourceId
        });
        return EMPTY;
      })
    ).subscribe();
  }
}

/**
 * Usage example — booking service with audit trail.
 */
@Injectable({ providedIn: 'root' })
export class BookingService {

  constructor(
    private readonly http: HttpClient,
    private readonly auditService: AuditService,
    private readonly logger: LoggerService
  ) {}

  createBooking(request: CreateBookingRequest): Observable<Booking> {
    return this.http.post<BookingDto>(`${environment.apiBaseUrl}/api/v1/bookings`, request).pipe(
      map(dto => BookingMapper.toDomain(dto)),
      tap(booking => {
        this.auditService.record(
          AuditAction.BOOKING_CREATE,
          'booking',
          booking.id,
          { newValue: { flightNumber: booking.flightNumber, pnr: booking.pnr } }
        );
        this.logger.info('Booking created', { bookingId: booking.id });
      })
    );
  }

  cancelBooking(bookingId: string, reason: string): Observable<void> {
    return this.http.delete<void>(
      `${environment.apiBaseUrl}/api/v1/bookings/${encodeURIComponent(bookingId)}`
    ).pipe(
      tap(() => {
        this.auditService.record(
          AuditAction.BOOKING_CANCEL,
          'booking',
          bookingId,
          { metadata: { reason } }
        );
        this.logger.info('Booking cancelled', { bookingId, reason });
      })
    );
  }
}
```

### 5.6 Security Event Logging

```typescript
/**
 * Logs security-relevant events: authentication attempts, authorization failures,
 * and suspicious activity. Feeds into SIEM and alerting pipelines.
 */
@Injectable({ providedIn: 'root' })
export class SecurityEventService {

  constructor(
    private readonly logger: LoggerService,
    private readonly auditService: AuditService
  ) {}

  logLoginAttempt(userId: string, success: boolean): void {
    const data = {
      eventType: 'AUTH_LOGIN',
      userId,
      success,
      ip: 'client-side', // Actual IP resolved by backend
      userAgent: navigator.userAgent,
      timestamp: Date.now()
    };

    if (success) {
      this.logger.info('User login successful', data);
      this.auditService.record(AuditAction.LOGIN, 'session', userId);
    } else {
      this.logger.warn('User login failed', data);
    }
  }

  logLogout(userId: string): void {
    this.logger.info('User logout', { eventType: 'AUTH_LOGOUT', userId });
    this.auditService.record(AuditAction.LOGOUT, 'session', userId);
  }

  logAuthorizationFailure(userId: string, resource: string, action: string): void {
    this.logger.warn('Authorization failure', {
      eventType: 'AUTH_FORBIDDEN',
      userId,
      resource,
      action,
      url: window.location.href
    });
  }

  logSuspiciousActivity(description: string, data?: Record<string, unknown>): void {
    this.logger.error(
      `Suspicious activity detected: ${description}`,
      new Error(description),
      {
        eventType: 'SECURITY_ALERT',
        ...data,
        url: window.location.href,
        userAgent: navigator.userAgent
      }
    );
  }
}
```

### 5.7 Health Check and Readiness Monitoring

```typescript
/**
 * Client-side health check service.
 * Periodically verifies connectivity to critical backend services
 * and reports status to the monitoring dashboard.
 */
@Injectable({ providedIn: 'root' })
export class HealthCheckService implements OnDestroy {

  private readonly destroy$ = new Subject<void>();
  private readonly healthEndpoint = `${environment.apiBaseUrl}/health`;

  private readonly statusSubject = new BehaviorSubject<HealthStatus>({
    healthy: true,
    lastCheck: new Date().toISOString(),
    services: {}
  });

  readonly status$ = this.statusSubject.asObservable();

  constructor(
    private readonly http: HttpClient,
    private readonly logger: LoggerService
  ) {}

  /**
   * Starts periodic health checks.
   * Interval is configurable — default 60 seconds.
   */
  startMonitoring(intervalMs: number = 60000): void {
    interval(intervalMs).pipe(
      takeUntil(this.destroy$),
      switchMap(() => this.checkHealth())
    ).subscribe();
  }

  private checkHealth(): Observable<HealthStatus> {
    return this.http.get<HealthCheckResponse>(this.healthEndpoint).pipe(
      timeout(5000),
      map(response => this.mapToHealthStatus(response, true)),
      catchError(error => {
        const status = this.mapToHealthStatus(null, false, error);
        this.logger.warn('Health check failed', {
          healthy: false,
          error: error.message ?? 'Unknown'
        });
        return of(status);
      }),
      tap(status => this.statusSubject.next(status))
    );
  }

  private mapToHealthStatus(
    response: HealthCheckResponse | null,
    healthy: boolean,
    error?: Error
  ): HealthStatus {
    return {
      healthy,
      lastCheck: new Date().toISOString(),
      services: response?.services ?? {},
      error: error?.message
    };
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

export interface HealthStatus {
  readonly healthy: boolean;
  readonly lastCheck: string;
  readonly services: Record<string, 'UP' | 'DOWN'>;
  readonly error?: string;
}

export interface HealthCheckResponse {
  readonly status: 'UP' | 'DOWN';
  readonly services: Record<string, 'UP' | 'DOWN'>;
}
```

### 5.8 Anti-Patterns

```typescript
// ❌ WRONG: Using console.log directly in production code
console.log('User loaded:', user);
// → Use LoggerService.debug('User loaded', { userId: user.id });

// ❌ WRONG: Logging sensitive data
this.logger.info('User authenticated', { token: authToken, password: userPassword });
// → Sanitize fields: this.logger.info('User authenticated', { userId: user.id });

// ❌ WRONG: Swallowing errors silently
catchError(() => of(null));
// → Log the error: catchError(err => { this.logger.error('Operation failed', err); return of(null); });

// ❌ WRONG: No correlation ID on outbound requests
this.http.get('/api/data').subscribe();
// → Use CorrelationIdInterceptor to attach X-Correlation-ID header automatically.

// ❌ WRONG: Logging stack traces in production
this.logger.error('Error', error, { stack: error.stack });
// → Stack traces may expose internal paths. Only include in non-production environments.

// ❌ WRONG: Audit-worthy operations without audit trail
this.http.delete(`/api/bookings/${id}`).subscribe();
// → this.auditService.record(AuditAction.BOOKING_CANCEL, 'booking', id);

// ❌ WRONG: Unbounded in-memory log buffer
this.buffer.push(entry); // No size limit, no flush — memory leak risk
// → Cap buffer size with batchSize and flush on interval and page unload.
```

---

## 6. Testing Standards

Testing is **non-negotiable**. All Angular code must follow the AA Engineering Atomic TDD Law (**ENG-4.1**): write a failing test, make it pass with the smallest change, refactor — in that order. Untested code does not ship.

### 6.0 Required Guidelines (Normative)

- **Atomic TDD (ENG-4.1)** is mandatory. Tests are written **before** production code, one behavior at a time.
- **Coverage thresholds** (enforced in CI):
  - Statements: **≥ 85%**
  - Branches: **≥ 80%**
  - Functions: **≥ 85%**
  - Lines: **≥ 85%**
- **Test pyramid (ENG-4.2)**: ~70% unit, ~20% component/integration, ~10% E2E. Inverted pyramids are rejected at code review.
- **Every component** must have at least one rendering test (`createComponent` + `detectChanges`) plus tests for all public `@Output()` emissions and key state transitions.
- **Every service** must have unit tests covering success path, error path, and edge cases (empty, null, boundary values).
- **No `fdescribe` / `fit` / `xdescribe` / `xit`** in committed code — fail the build on detection.
- **No real HTTP, timers, or `Date.now()`** in unit tests — always use `HttpTestingController`, `fakeAsync`, and injected clocks/`DatePipe`.
- **Accessibility tests** (`axe-core`) must run against every page-level component.
- **E2E tests** must be deterministic — no `waitFor(2000)` arbitrary sleeps. Use proper element/state waits.

### 6.1 Test Tooling Standards

| Concern | Standard | Notes |
|---------|----------|-------|
| Unit / Component runner | **Jest** (preferred) or Karma + Jasmine | Jest is faster, supports parallelization, and has better watch mode |
| E2E runner | **Playwright** (preferred) or Cypress | Playwright supports multi-browser, multi-tab, and network mocking natively |
| Component harnesses | `@angular/cdk/testing` | Use Material harnesses instead of querying DOM internals |
| Mocking HTTP | `HttpTestingController` from `@angular/common/http/testing` | Never mock `HttpClient` directly with spies |
| NgRx testing | `@ngrx/store/testing` (`provideMockStore`), `@ngrx/effects/testing` (`provideMockActions`) | Use marble testing (`jasmine-marbles` / `jest-marbles`) for complex effect streams |
| Signal Store testing | Direct method invocation + signal reads | No special harness required |
| Accessibility | `@axe-core/playwright` (E2E) and `jest-axe` (unit) | Run on every page-level component |
| Visual regression | Chromatic, Percy, or Playwright snapshots | Required for design-system components |
| Coverage | Built-in (`jest --coverage` or `karma-coverage`) | Reported to SonarQube via lcov |

### 6.2 Unit Testing — Services

```typescript
/**
 * Service test: HTTP service with HttpTestingController.
 * Covers success, error, and parameter encoding.
 */
describe('UserService', () => {

  let service: UserService;
  let httpMock: HttpTestingController;

  const apiUrl = `${environment.apiBaseUrl}/api/v1/users`;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [
        UserService,
        { provide: ErrorHandlerService, useValue: { handleError: jest.fn() } },
        { provide: LoggerService, useValue: createLoggerMock() }
      ]
    });

    service = TestBed.inject(UserService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();  // Asserts no outstanding requests
  });

  describe('getUsers', () => {

    it('should fetch users and map DTOs to domain models', (done) => {
      const dtoFixture: UserDto[] = [
        { id: '1', email: 'a@x.com', first_name: 'Ada', last_name: 'Lovelace',
          phone_number: null, status: 'ACTIVE', created_at: '2026-01-01T00:00:00Z',
          updated_at: '2026-01-01T00:00:00Z', address: null }
      ];

      service.getUsers().subscribe(response => {
        expect(response.data).toHaveLength(1);
        expect(response.data[0].fullName).toBe('Ada Lovelace');
        expect(response.data[0].createdAt).toBeInstanceOf(Date);
        done();
      });

      const req = httpMock.expectOne(req => req.url === apiUrl && req.method === 'GET');
      req.flush({ data: dtoFixture, pagination: { currentPage: 1, pageSize: 20, totalItems: 1, totalPages: 1 } });
    });

    it('should encode query parameters correctly', () => {
      service.getUsers({ page: 2, status: 'ACTIVE' }).subscribe();

      const req = httpMock.expectOne(r => r.url === apiUrl);
      expect(req.request.params.get('page')).toBe('2');
      expect(req.request.params.get('status')).toBe('ACTIVE');
      req.flush({ data: [], pagination: { currentPage: 2, pageSize: 20, totalItems: 0, totalPages: 0 } });
    });

    it('should propagate HTTP errors through the error handler', (done) => {
      service.getUsers().subscribe({
        error: (error) => {
          expect(error.status).toBe(500);
          done();
        }
      });

      const req = httpMock.expectOne(apiUrl);
      req.flush('Server error', { status: 500, statusText: 'Internal Server Error' });
    });
  });
});

function createLoggerMock(): jest.Mocked<LoggerService> {
  return {
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  } as unknown as jest.Mocked<LoggerService>;
}
```

### 6.3 Component Testing — Presentational Components

```typescript
/**
 * Presentational component test: Inputs render correctly, outputs emit on user action.
 */
describe('UserCardComponent', () => {

  let component: UserCardComponent;
  let fixture: ComponentFixture<UserCardComponent>;

  const userFixture: User = {
    id: '1', email: 'a@x.com', firstName: 'Ada', lastName: 'Lovelace',
    fullName: 'Ada Lovelace', phoneNumber: null, status: UserStatus.Active,
    createdAt: new Date('2026-01-01'), updatedAt: new Date('2026-01-01'), address: null
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [UserCardComponent],
      imports: [MatCardModule]
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
  });

  it('should render the user full name and email', () => {
    component.user = userFixture;
    fixture.detectChanges();

    const title = fixture.nativeElement.querySelector('mat-card-title');
    const subtitle = fixture.nativeElement.querySelector('mat-card-subtitle');

    expect(title.textContent).toContain('Ada Lovelace');
    expect(subtitle.textContent).toContain('a@x.com');
  });

  it('should apply the correct CSS class for user status', () => {
    component.user = { ...userFixture, status: UserStatus.Suspended };
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.badge');
    expect(badge.classList).toContain('badge-suspended');
  });

  it('should not re-render when an unrelated input changes (OnPush)', () => {
    component.user = userFixture;
    fixture.detectChanges();

    const titleBefore = fixture.nativeElement.querySelector('mat-card-title').textContent;

    // Mutating the same reference must NOT trigger re-render under OnPush
    (component.user as any).firstName = 'Mutated';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('mat-card-title').textContent).toBe(titleBefore);
  });
});
```

### 6.4 Component Testing — Container Components with NgRx

```typescript
/**
 * Container component test: Uses MockStore to verify dispatched actions
 * and selector subscriptions without instantiating real reducers.
 */
describe('UserListContainerComponent', () => {

  let component: UserListContainerComponent;
  let fixture: ComponentFixture<UserListContainerComponent>;
  let store: MockStore;

  const initialState = {
    users: { users: [], loading: false, error: null, selectedUserId: null,
             pagination: { currentPage: 1, pageSize: 20, totalItems: 0, totalPages: 0 } }
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [UserListContainerComponent, MockUserListComponent],
      providers: [provideMockStore({ initialState })]
    }).compileComponents();

    store = TestBed.inject(MockStore);
    jest.spyOn(store, 'dispatch');

    fixture = TestBed.createComponent(UserListContainerComponent);
    component = fixture.componentInstance;
  });

  it('should dispatch loadUsers on init', () => {
    fixture.detectChanges();
    expect(store.dispatch).toHaveBeenCalledWith(UsersActions.loadUsers());
  });

  it('should dispatch deleteUser when child emits userDeleted', () => {
    fixture.detectChanges();
    component.onUserDeleted('user-123');
    expect(store.dispatch).toHaveBeenCalledWith(UsersActions.deleteUser({ userId: 'user-123' }));
  });

  it('should expose users$ from selectAllUsers selector', (done) => {
    store.overrideSelector(selectAllUsers, [
      { id: '1', fullName: 'Ada' } as User
    ]);
    store.refreshState();
    fixture.detectChanges();

    component.users$.subscribe(users => {
      expect(users).toHaveLength(1);
      expect(users[0].fullName).toBe('Ada');
      done();
    });
  });
});
```

### 6.5 NgRx Effects Testing

```typescript
/**
 * Effects test: Uses provideMockActions to feed actions into the effect
 * and asserts the resulting action stream.
 */
describe('UsersEffects', () => {

  let actions$: Observable<Action>;
  let effects: UsersEffects;
  let userService: jest.Mocked<UserService>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        UsersEffects,
        provideMockActions(() => actions$),
        {
          provide: UserService,
          useValue: { getUsers: jest.fn(), createUser: jest.fn(), deleteUser: jest.fn() }
        }
      ]
    });

    effects = TestBed.inject(UsersEffects);
    userService = TestBed.inject(UserService) as jest.Mocked<UserService>;
  });

  describe('loadUsers$', () => {

    it('should dispatch loadUsersSuccess on successful API call', (done) => {
      const users: User[] = [{ id: '1', fullName: 'Ada' } as User];
      const pagination = { currentPage: 1, pageSize: 20, totalItems: 1, totalPages: 1 };
      userService.getUsers.mockReturnValue(of({ data: users, pagination }));

      actions$ = of(UsersActions.loadUsers({}));

      effects.loadUsers$.subscribe(action => {
        expect(action).toEqual(UsersActions.loadUsersSuccess({ users, pagination }));
        done();
      });
    });

    it('should dispatch loadUsersFailure on API error', (done) => {
      userService.getUsers.mockReturnValue(throwError(() => new Error('boom')));

      actions$ = of(UsersActions.loadUsers({}));

      effects.loadUsers$.subscribe(action => {
        expect(action).toEqual(UsersActions.loadUsersFailure({ error: 'boom' }));
        done();
      });
    });
  });
});
```

### 6.6 Reactive Form Testing

```typescript
describe('UserFormService', () => {

  let service: UserFormService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        UserFormService,
        FormBuilder,
        { provide: UserValidatorService, useValue: { uniqueEmailValidator: () => () => of(null) } }
      ]
    });
    service = TestBed.inject(UserFormService);
  });

  it('should create a form with required validators', () => {
    const form = service.createForm();

    expect(form.get('email')?.hasError('required')).toBe(true);
    expect(form.get('firstName')?.hasError('required')).toBe(true);
    expect(form.get('lastName')?.hasError('required')).toBe(true);
  });

  it('should reject invalid email formats', () => {
    const form = service.createForm();
    form.patchValue({ email: 'not-an-email' });
    expect(form.get('email')?.hasError('email')).toBe(true);
  });

  it('should accept valid input across all required fields', () => {
    const form = service.createForm();
    form.patchValue({
      email: 'ada@example.com',
      firstName: 'Ada',
      lastName: 'Lovelace',
      address: { street: '1 Main', city: 'Dallas', state: 'TX', zipCode: '75201', country: 'USA' }
    });

    expect(form.get('email')?.valid).toBe(true);
    expect(form.get('firstName')?.valid).toBe(true);
  });
});
```

### 6.7 Asynchronous Testing — fakeAsync and Marbles

```typescript
/**
 * fakeAsync: Synchronously advance timers, schedulers, and microtasks.
 * Use for debouncing, throttling, and setTimeout-based code.
 */
it('should debounce search input by 300ms', fakeAsync(() => {
  const search = jest.fn();
  component.searchControl.valueChanges
    .pipe(debounceTime(300))
    .subscribe(search);

  component.searchControl.setValue('a');
  component.searchControl.setValue('ab');
  component.searchControl.setValue('abc');

  tick(299);
  expect(search).not.toHaveBeenCalled();

  tick(1);
  expect(search).toHaveBeenCalledTimes(1);
  expect(search).toHaveBeenCalledWith('abc');
}));

/**
 * Marble testing: Assert RxJS stream timing.
 */
it('should emit loading=true then loading=false around HTTP call', () => {
  const scheduler = new TestScheduler((actual, expected) => {
    expect(actual).toEqual(expected);
  });

  scheduler.run(({ cold, expectObservable }) => {
    const httpResponse$ = cold('---a|', { a: { data: [] } });
    jest.spyOn(userService, 'getUsers').mockReturnValue(httpResponse$);

    const result$ = component.loadUsersWithLoadingFlag();
    expectObservable(result$).toBe('a--b|', { a: true, b: false });
  });
});
```

### 6.8 E2E Testing — Playwright

```typescript
/**
 * E2E test using the Page Object pattern.
 * Tests are deterministic, isolated, and use proper element waits.
 */
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/login.page';
import { UserListPage } from './pages/user-list.page';

test.describe('User management', () => {

  test.beforeEach(async ({ page }) => {
    const login = new LoginPage(page);
    await login.goto();
    await login.loginAs('user.manager@company.com');
  });

  test('should create a new user and display it in the list', async ({ page }) => {
    const userList = new UserListPage(page);
    await userList.goto();

    await userList.clickCreateUser();
    await userList.fillUserForm({
      email: `e2e-${Date.now()}@example.com`,
      firstName: 'E2E',
      lastName: 'Test'
    });
    await userList.submitForm();

    await expect(userList.successToast).toBeVisible();
    await expect(userList.row('E2E Test')).toBeVisible();
  });

  test('should be accessible (axe scan)', async ({ page }) => {
    const userList = new UserListPage(page);
    await userList.goto();

    const { default: AxeBuilder } = await import('@axe-core/playwright');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });
});

/**
 * Page Object — encapsulates selectors and actions for one page.
 */
export class UserListPage {

  constructor(private readonly page: Page) {}

  readonly successToast = this.page.locator('[data-test="toast-success"]');

  async goto(): Promise<void> {
    await this.page.goto('/users');
    await this.page.waitForSelector('[data-test="user-list"]');
  }

  row(name: string) {
    return this.page.locator(`[data-test="user-row"]`, { hasText: name });
  }

  async clickCreateUser(): Promise<void> {
    await this.page.click('[data-test="create-user-button"]');
  }

  async fillUserForm(input: { email: string; firstName: string; lastName: string }): Promise<void> {
    await this.page.fill('[data-test="email-input"]', input.email);
    await this.page.fill('[data-test="first-name-input"]', input.firstName);
    await this.page.fill('[data-test="last-name-input"]', input.lastName);
  }

  async submitForm(): Promise<void> {
    await this.page.click('[data-test="submit-button"]');
  }
}
```

### 6.9 Accessibility Testing (Mandatory)

```typescript
/**
 * Unit-level a11y check using jest-axe.
 * Required for every page-level component.
 */
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

it('should have no accessibility violations', async () => {
  fixture.detectChanges();
  const results = await axe(fixture.nativeElement);
  expect(results).toHaveNoViolations();
});
```

### 6.10 Test Data Management

- Centralize fixtures in `*.mock.ts` or `*.fixture.ts` files. **Never duplicate** test data across spec files.
- Use **builder functions** for entities with many fields: `aUser().withStatus('ACTIVE').build()`.
- E2E tests **must not** depend on production data. Use a dedicated test environment with seeded data or per-test setup/teardown.
- **Never commit** real PII, real tokens, or real credentials in fixtures.

```typescript
/**
 * Test data builder — produces minimal valid fixtures with optional overrides.
 */
export function aUser(overrides: Partial<User> = {}): User {
  return {
    id: 'test-user-id',
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    fullName: 'Test User',
    phoneNumber: null,
    status: UserStatus.Active,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    address: null,
    ...overrides
  };
}
```

### 6.11 Anti-Patterns

```typescript
// ❌ WRONG: fdescribe / fit committed to main
fdescribe('UserService', () => { /* ... */ });
// → CI must fail on focused tests. Add an ESLint rule (no-focused-tests).

// ❌ WRONG: Real HTTP in unit tests
it('should fetch users', (done) => {
  http.get('https://api.real.com/users').subscribe(done);  // BAD
});
// → Use HttpTestingController. Real HTTP causes flaky, slow, dependent tests.

// ❌ WRONG: Mocking HttpClient with spies
const httpSpy = jasmine.createSpyObj('HttpClient', ['get']);
httpSpy.get.and.returnValue(of([]));
// → Use HttpClientTestingModule + HttpTestingController for verifiable, idiomatic tests.

// ❌ WRONG: Arbitrary sleeps in E2E
await page.waitForTimeout(2000);  // Flaky and slow
// → await expect(locator).toBeVisible();  — wait for the actual condition.

// ❌ WRONG: Asserting implementation details
expect(component['privateMethod']).toHaveBeenCalled();
// → Test observable behavior (rendered output, emitted events, dispatched actions),
//   not internal calls.

// ❌ WRONG: One giant test that asserts everything
it('should handle the entire user lifecycle', () => {
  // 200 lines of arrange/act/assert
});
// → One test, one behavior. Use describe blocks to group.

// ❌ WRONG: Tests that depend on each other
it('test A: creates a user', () => { /* sets shared state */ });
it('test B: deletes the user from test A', () => { /* depends on A */ });
// → Each test must be independent and runnable in isolation/parallel.
```

---

## 7. Code Quality & Maintenance

Code quality is enforced automatically. Manual review confirms intent and design; tooling enforces consistency, complexity, and security baselines.

### 7.0 Required Guidelines (Normative)

- **TypeScript strict mode** is mandatory. All flags below must be `true`.
- **ESLint must pass with zero errors and zero warnings** before merge. Warnings are treated as errors in CI.
- **Prettier** is the single source of truth for formatting. No manual style debates.
- **Husky + lint-staged** pre-commit hooks must run lint and format on staged files.
- **SonarQube quality gate** must pass: 0 bugs, 0 vulnerabilities, 0 security hotspots, code smells below threshold, ≥ 85% coverage on new code, 0 duplicated blocks > 3% on new code.
- **Cyclomatic complexity** per function ≤ **10**. Cognitive complexity ≤ **15**.
- **Function length** ≤ **50 lines**. **File length** ≤ **400 lines** (excluding generated and test fixture files).
- **No `any`** unless documented with `// eslint-disable-next-line @typescript-eslint/no-explicit-any` and a justifying comment.
- **No commented-out code** in committed files. Delete it — Git preserves history.
- **No `TODO` / `FIXME`** without an associated tracked issue: `// TODO(JIRA-1234): description`.

### 7.1 TypeScript Strict Configuration

```jsonc
// tsconfig.json — Mandatory compiler options
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true,

    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUncheckedIndexedAccess": true,

    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": false,
    "esModuleInterop": true,
    "isolatedModules": true,

    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "useDefineForClassFields": false,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "angularCompilerOptions": {
    "strictTemplates": true,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "enableI18nLegacyMessageIdFormat": false
  }
}
```

### 7.2 ESLint Configuration

```jsonc
// .eslintrc.json
{
  "root": true,
  "ignorePatterns": ["projects/**/*", "dist/**/*", "coverage/**/*"],
  "overrides": [
    {
      "files": ["*.ts"],
      "extends": [
        "eslint:recommended",
        "plugin:@typescript-eslint/recommended",
        "plugin:@typescript-eslint/recommended-requiring-type-checking",
        "plugin:@angular-eslint/recommended",
        "plugin:@angular-eslint/template/process-inline-templates",
        "plugin:rxjs/recommended",
        "plugin:sonarjs/recommended",
        "plugin:security/recommended",
        "plugin:prettier/recommended"
      ],
      "parserOptions": { "project": ["tsconfig.json"], "createDefaultProgram": true },
      "rules": {
        "@angular-eslint/component-selector": ["error", { "type": "element", "prefix": "app", "style": "kebab-case" }],
        "@angular-eslint/directive-selector": ["error", { "type": "attribute", "prefix": "app", "style": "camelCase" }],
        "@angular-eslint/use-lifecycle-interface": "error",
        "@angular-eslint/no-output-on-prefix": "error",
        "@angular-eslint/no-input-rename": "error",
        "@angular-eslint/no-output-rename": "error",
        "@angular-eslint/prefer-on-push-component-change-detection": "error",

        "@typescript-eslint/no-explicit-any": "error",
        "@typescript-eslint/no-non-null-assertion": "error",
        "@typescript-eslint/explicit-member-accessibility": ["error", { "accessibility": "explicit", "overrides": { "constructors": "no-public" } }],
        "@typescript-eslint/no-floating-promises": "error",
        "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
        "@typescript-eslint/prefer-readonly": "error",
        "@typescript-eslint/consistent-type-imports": "error",

        "rxjs/no-unsafe-takeuntil": "error",
        "rxjs/no-ignored-subscription": "error",
        "rxjs/no-nested-subscribe": "error",
        "rxjs/no-async-subscribe": "error",
        "rxjs/throw-error": "error",

        "sonarjs/cognitive-complexity": ["error", 15],
        "sonarjs/no-duplicate-string": ["error", { "threshold": 3 }],
        "sonarjs/no-identical-functions": "error",

        "complexity": ["error", 10],
        "max-lines-per-function": ["error", { "max": 50, "skipBlankLines": true, "skipComments": true }],
        "max-lines": ["error", { "max": 400, "skipBlankLines": true, "skipComments": true }],
        "max-depth": ["error", 4],
        "max-params": ["error", 5],
        "no-console": ["error", { "allow": ["warn", "error"] }],
        "no-debugger": "error",
        "no-alert": "error",
        "no-eval": "error",
        "no-implied-eval": "error",
        "prefer-const": "error",
        "eqeqeq": ["error", "always"],
        "curly": ["error", "all"],
        "no-restricted-imports": ["error", { "patterns": ["rxjs/internal/*", "../../../*"] }],
        "no-restricted-syntax": [
          "error",
          { "selector": "CallExpression[callee.name='fdescribe']", "message": "Focused tests are not allowed." },
          { "selector": "CallExpression[callee.name='fit']", "message": "Focused tests are not allowed." }
        ]
      }
    },
    {
      "files": ["*.html"],
      "extends": ["plugin:@angular-eslint/template/recommended", "plugin:@angular-eslint/template/accessibility"],
      "rules": {
        "@angular-eslint/template/no-any": "error",
        "@angular-eslint/template/no-call-expression": "warn",
        "@angular-eslint/template/use-track-by-function": "error"
      }
    }
  ]
}
```

### 7.3 Prettier Configuration

```jsonc
// .prettierrc
{
  "printWidth": 120,
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "quoteProps": "as-needed",
  "trailingComma": "none",
  "bracketSpacing": true,
  "arrowParens": "always",
  "endOfLine": "lf",
  "overrides": [
    { "files": "*.html", "options": { "parser": "angular" } },
    { "files": "*.md", "options": { "proseWrap": "preserve" } }
  ]
}
```

### 7.4 Pre-Commit Hooks (Husky + lint-staged)

```jsonc
// package.json (excerpt)
{
  "scripts": {
    "prepare": "husky install",
    "lint": "ng lint",
    "lint:fix": "ng lint --fix",
    "format": "prettier --write \"src/**/*.{ts,html,scss,json}\"",
    "format:check": "prettier --check \"src/**/*.{ts,html,scss,json}\"",
    "test:ci": "ng test --watch=false --code-coverage --browsers=ChromeHeadless"
  },
  "lint-staged": {
    "*.ts": ["eslint --fix --max-warnings=0", "prettier --write"],
    "*.html": ["eslint --fix --max-warnings=0", "prettier --write"],
    "*.{scss,json,md}": ["prettier --write"]
  }
}
```

```bash
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
npx lint-staged

# .husky/commit-msg
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
npx --no -- commitlint --edit "$1"
```

### 7.5 Conventional Commits

All commit messages **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

| Type | Use For |
|------|---------|
| `feat` | New feature (correlates with MINOR semver bump) |
| `fix` | Bug fix (correlates with PATCH semver bump) |
| `docs` | Documentation only |
| `style` | Formatting, whitespace, no code change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Build system, dependencies, tooling |
| `ci` | CI/CD configuration |
| `chore` | Routine maintenance |
| `revert` | Reverts a previous commit |

Breaking changes use `!` after the type/scope and a `BREAKING CHANGE:` footer.

```
feat(users)!: drop support for legacy username field

Removes the deprecated 'username' field from UserDto.
Consumers must migrate to 'email' as the unique identifier.

BREAKING CHANGE: UserDto.username has been removed.
Refs: JIRA-2345
```

### 7.6 Code Review Checklist

**Architecture & Design**
- [ ] Component follows smart/dumb separation (Section 1.1)
- [ ] State management approach matches the decision matrix (Section 1.2)
- [ ] No business logic in components or templates
- [ ] DTOs and domain models are separated; mappers are pure functions (Section 1.3)
- [ ] Services use constructor injection with `private readonly` (Section 1.4)
- [ ] No SOLID principle violations (Section 2.1)

**Performance**
- [ ] `ChangeDetectionStrategy.OnPush` on every component (Section 4.1)
- [ ] `trackBy` on every `*ngFor` / `@for`
- [ ] No function calls in templates
- [ ] Heavy libraries are dynamically imported (Section 4.2.2)
- [ ] Bundle budgets respected

**Security**
- [ ] No bypassed sanitization without security review (Section 3.1.1)
- [ ] No PII/PCI in `localStorage`, `sessionStorage`, URLs, or logs (Section 3.2.2)
- [ ] All routes have appropriate guards (Section 3.4)
- [ ] All user input is validated client-side (UX) and server-side (security)

**Resilience & Observability**
- [ ] HTTP calls have timeout, retry (idempotent only), and error handling (Section 4.3)
- [ ] Subscriptions are unsubscribed (`takeUntilDestroyed` / `async` pipe) (Section 4.6)
- [ ] Errors are logged via `LoggerService`, not `console.log` (Section 5.1)
- [ ] Audit-worthy operations record audit events (Section 5.5)

**Testing**
- [ ] New code follows Atomic TDD (test-first commits visible in history)
- [ ] Coverage thresholds met for modified files
- [ ] No `fdescribe` / `fit`
- [ ] E2E tests are deterministic (no arbitrary sleeps)
- [ ] Accessibility test included for page-level components

**Quality**
- [ ] ESLint, Prettier, and TypeScript compile with zero warnings
- [ ] No `any`, no `!` non-null assertions without justification
- [ ] Function complexity ≤ 10, length ≤ 50 lines
- [ ] No commented-out code, no untracked TODOs

### 7.7 SonarQube Quality Gate

Required gate (configured in SonarQube and enforced in CI):

| Metric | Threshold (New Code) |
|--------|---------------------|
| Bugs | 0 |
| Vulnerabilities | 0 |
| Security Hotspots Reviewed | 100% |
| Coverage | ≥ 85% |
| Duplicated Lines | ≤ 3% |
| Maintainability Rating | A |
| Reliability Rating | A |
| Security Rating | A |

The `agent-quality-0003-sonarqube-reviewer.md` agent is the canonical tool for triaging SonarQube findings before merge.

### 7.8 Documentation Standards

- **JSDoc** is required on every exported `public` symbol: services, components (class-level), pipes, directives, models, and module-level functions.
- **README.md** is required at the root of every feature module describing purpose, key components, state ownership, and external dependencies.
- **ADRs** (Architecture Decision Records) must be created in `runtimes/angular/adrs/` for any decision that:
  - Adds, removes, or replaces a major dependency
  - Changes a cross-cutting pattern (state, routing, auth, error handling)
  - Introduces a deviation from this guide
- **Compodoc** runs in CI and publishes generated docs alongside each release.

```typescript
/**
 * Loads the paginated list of users matching the supplied query.
 *
 * Caching: Results are cached for 5 minutes via the {@link CachingApiClient} decorator.
 * Errors:  Network and 5xx errors are retried 3 times with exponential backoff.
 *          4xx errors are propagated to the caller without retry.
 *
 * @param params Optional filter/sort/pagination parameters
 * @returns Paginated user response with mapped domain models
 * @throws AppError with code `TIMEOUT` if the request exceeds 10 seconds
 *
 * @example
 * userService.getUsers({ page: 1, status: UserStatus.Active })
 *   .subscribe(response => console.log(response.data));
 */
public getUsers(params?: UserQueryParams): Observable<PaginatedResponse<User>> {
  // ...
}
```

### 7.9 Dependency Management

- Use **npm** (not Yarn or pnpm) for consistency across the organization unless otherwise approved.
- Always commit `package-lock.json`. Never commit `node_modules`.
- Pin Angular and `@ngrx/*` packages to the same major version. Mixed majors are rejected.
- Use **Renovate** or **Dependabot** for automated update PRs. Review weekly.
- Run `npm outdated` quarterly. Document and schedule upgrades in the team backlog.
- Audit new dependencies before adding (Section 3.6).

### 7.10 Continuous Integration Pipeline

Every PR must pass the following gates **in order**:

1. **Install** — `npm ci` (uses lock file, never updates)
2. **Lint** — `npm run lint` and `npm run format:check` (zero warnings)
3. **Build** — `ng build --configuration=production` (bundle budgets enforced)
4. **Unit + component tests** — `npm run test:ci` (coverage thresholds enforced)
5. **E2E smoke** — Playwright critical-path suite against ephemeral environment
6. **Security audit** — `npm audit --audit-level=high` and `lockfile-lint`
7. **SonarQube scan** — Quality gate must pass
8. **Bundle analysis** — Compare against baseline; flag PRs that increase initial bundle by > 5%

A merge is **blocked** if any gate fails. No exceptions without architecture board approval.

### 7.11 Anti-Patterns

```typescript
// ❌ WRONG: Disabling lint rules without justification
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const data: any = response;
// → If `any` is truly required, document why in a comment AND open a tech-debt ticket.

// ❌ WRONG: Non-null assertion to silence the compiler
const user = this.users.find(u => u.id === id)!;
// → Handle the null case: throw, return Observable error, or default value.

// ❌ WRONG: Commented-out code
// const oldImpl = this.legacyService.fetch();
// if (oldImpl) { /* ... */ }
// → Delete it. Git history preserves the old code if needed.

// ❌ WRONG: Untracked TODOs
// TODO: fix this someday
// → // TODO(JIRA-1234): description — must reference a tracked issue.

// ❌ WRONG: Magic numbers and strings scattered throughout code
if (user.attempts > 3) { /* ... */ }
if (user.role === 'admin') { /* ... */ }
// → Use named constants and enums:
//    const MAX_LOGIN_ATTEMPTS = 3;
//    enum Role { Admin = 'admin', ... }

// ❌ WRONG: Functions that do too many things
function processUser(user: User): void {
  validate(user);
  enrich(user);
  save(user);
  notify(user);
  audit(user);
  email(user);
}
// → One function, one responsibility. Compose smaller functions or use a facade.

// ❌ WRONG: Skipping the lock file
npm install --no-package-lock
// → Always commit package-lock.json. Reproducible builds depend on it.
```

---

## Governance

This standards guide is the authoritative reference for all Angular development within the organization. All code must comply with these standards unless explicitly approved by the Architecture Review Board.

### Compliance
- All pull requests must pass automated quality gates (ESLint, Karma/Jest tests, security scans)
- Code reviews must verify adherence to these standards
- Exceptions require documented justification and approval

### Amendments
- Standards are reviewed quarterly
- Proposed changes must be submitted to the Architecture Review Board
- Major changes require team consensus and migration plan

### Continuous Improvement
- Teams are encouraged to suggest improvements
- New patterns and practices should be documented and shared
- Regular training sessions on standards compliance

**Version**: 1.0.0  
**Ratified**: April 22, 2026  
**Last Amended**: April 22, 2026  
**Next Review**: July 22, 2026

---

## Additional Resources

- [Angular Official Documentation](https://angular.io/docs)
- [Angular Style Guide](https://angular.io/guide/styleguide)
- [NgRx Documentation](https://ngrx.io/docs)
- [RxJS Official Guide](https://rxjs.dev/guide/overview)
- [Angular Material](https://material.angular.io/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/)
- [Clean Architecture by Robert C. Martin](https://www.oreilly.com/library/view/clean-architecture-a/9780134494166/)
- [Refactoring UI](https://www.refactoringui.com/)

---

*This guide is a living document and will be updated as new best practices emerge and technologies evolve.*
