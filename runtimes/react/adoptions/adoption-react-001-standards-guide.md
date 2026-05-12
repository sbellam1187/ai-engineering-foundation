# React Standards Guide
*Development Standards for React Applications*

**Version:** 1.0.0  
**Last Updated:** April 9th, 2026  
**Status:** 

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
├── api/                  # API client layer (Axios/fetch wrappers)
│   ├── clients/         # API client instances & interceptors
│   ├── endpoints/       # Endpoint definitions by domain
│   └── types/           # API request/response TypeScript types
├── components/           # Reusable UI components
│   ├── common/          # Shared primitives (Button, Input, Modal)
│   ├── layout/          # Layout components (Header, Footer, Sidebar)
│   └── feedback/        # Feedback components (Toast, Alert, Spinner)
├── features/             # Feature-based modules (domain-driven)
│   ├── users/           # User feature module
│   │   ├── components/  # Feature-specific components
│   │   ├── hooks/       # Feature-specific custom hooks
│   │   ├── pages/       # Route-level page components
│   │   ├── services/    # Feature business logic
│   │   ├── store/       # Feature state (slice/context)
│   │   ├── types/       # Feature TypeScript types
│   │   ├── utils/       # Feature utility functions
│   │   └── __tests__/   # Feature tests
│   └── orders/          # Order feature module (same structure)
├── hooks/                # Shared custom hooks
├── store/                # Global state management (Redux/Zustand)
│   ├── slices/          # Redux slices or Zustand stores
│   ├── middleware/       # Custom middleware
│   └── selectors/       # Reusable selectors
├── context/              # React Context providers
├── routes/               # Route configuration
├── styles/               # Global styles and theme
│   ├── theme/           # Design tokens, theme config
│   └── global/          # CSS reset, global styles
├── utils/                # Shared utility functions
├── constants/            # Application-wide constants
├── types/                # Global TypeScript types and interfaces
├── config/               # App configuration (env, feature flags)
├── App.tsx               # Root application component
├── main.tsx              # Application entry point
└── vite-env.d.ts         # Vite type declarations
```

#### Layer Responsibilities

**API Layer (api/)**
```tsx
/**
 * API layer responsibilities:
 * - HTTP request configuration & interceptors
 * - Request/response type definitions
 * - Error response normalization
 * - Authentication token injection
 * - NO business logic
 * - NO UI rendering
 */

// api/clients/httpClient.ts
import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios';

const httpClient: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: attach auth token
httpClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('accessToken');
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error: AxiosError) => Promise.reject(error)
);

// Response interceptor: normalize errors
httpClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Redirect to login or refresh token
      window.dispatchEvent(new CustomEvent('auth:unauthorized'));
    }
    return Promise.reject(normalizeError(error));
  }
);

export default httpClient;
```

```tsx
// api/endpoints/userApi.ts
import httpClient from '../clients/httpClient';
import type { User, CreateUserRequest, UpdateUserRequest } from '../types/user';
import type { PaginatedResponse, PaginationParams } from '../types/common';

/**
 * User API endpoint definitions.
 * Each function maps to a single REST endpoint.
 */
export const userApi = {
  getById: (id: string): Promise<User> =>
    httpClient.get(`/api/v1/users/${id}`).then((res) => res.data),

  list: (params: PaginationParams): Promise<PaginatedResponse<User>> =>
    httpClient.get('/api/v1/users', { params }).then((res) => res.data),

  create: (data: CreateUserRequest): Promise<User> =>
    httpClient.post('/api/v1/users', data).then((res) => res.data),

  update: (id: string, data: UpdateUserRequest): Promise<User> =>
    httpClient.put(`/api/v1/users/${id}`, data).then((res) => res.data),

  delete: (id: string): Promise<void> =>
    httpClient.delete(`/api/v1/users/${id}`),
};
```

**Feature/Page Layer (features/)**
```tsx
/**
 * Page component responsibilities:
 * - Route-level entry point
 * - Compose feature components
 * - Coordinate data loading (via hooks)
 * - Handle route parameters
 * - NO direct API calls
 * - NO complex business logic
 */

// features/users/pages/UserListPage.tsx
import { useUsers } from '../hooks/useUsers';
import { UserTable } from '../components/UserTable';
import { UserFilters } from '../components/UserFilters';
import { PageLayout } from '@/components/layout/PageLayout';
import { ErrorBoundary } from '@/components/feedback/ErrorBoundary';
import { LoadingSpinner } from '@/components/feedback/LoadingSpinner';

export const UserListPage: React.FC = () => {
  const { users, isLoading, error, filters, setFilters, pagination } = useUsers();

  if (error) {
    return <ErrorBoundary error={error} />;
  }

  return (
    <PageLayout title="Users">
      <UserFilters filters={filters} onFilterChange={setFilters} />
      {isLoading ? (
        <LoadingSpinner />
      ) : (
        <UserTable users={users} pagination={pagination} />
      )}
    </PageLayout>
  );
};
```

**Custom Hooks Layer (hooks/)**
```tsx
/**
 * Custom hook responsibilities:
 * - Data fetching orchestration
 * - State management bridge
 * - Business logic coordination
 * - Side effect management
 * - Reusable stateful logic
 * - NO UI rendering
 */

// features/users/hooks/useUsers.ts
import { useState, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import { userApi } from '@/api/endpoints/userApi';
import type { UserFilters, PaginationParams } from '../types';

export function useUsers() {
  const [filters, setFilters] = useState<UserFilters>({
    status: undefined,
    search: '',
  });

  const [pagination, setPagination] = useState<PaginationParams>({
    page: 0,
    size: 20,
    sort: 'createdAt,desc',
  });

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['users', filters, pagination],
    queryFn: () => userApi.list({ ...filters, ...pagination }),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });

  const handleFilterChange = useCallback((newFilters: Partial<UserFilters>) => {
    setFilters((prev) => ({ ...prev, ...newFilters }));
    setPagination((prev) => ({ ...prev, page: 0 })); // Reset to first page
  }, []);

  return {
    users: data?.content ?? [],
    totalElements: data?.totalElements ?? 0,
    isLoading,
    error,
    filters,
    setFilters: handleFilterChange,
    pagination,
    setPagination,
    refetch,
  };
}
```

**Component Layer (components/)**
```tsx
/**
 * Component responsibilities:
 * - UI rendering and visual presentation
 * - User interaction handling (events)
 * - Props-driven configuration
 * - Accessibility (ARIA attributes)
 * - NO API calls
 * - NO business logic
 * - NO direct state store access (receive data via props/hooks)
 */

// features/users/components/UserTable.tsx
import type { User } from '../types';
import type { PaginatedResponse } from '@/api/types/common';

interface UserTableProps {
  users: User[];
  pagination: PaginatedResponse<User>;
  onRowClick?: (user: User) => void;
}

export const UserTable: React.FC<UserTableProps> = ({
  users,
  pagination,
  onRowClick,
}) => {
  return (
    <table role="table" aria-label="Users list">
      <thead>
        <tr>
          <th scope="col">Name</th>
          <th scope="col">Email</th>
          <th scope="col">Status</th>
          <th scope="col">Created</th>
        </tr>
      </thead>
      <tbody>
        {users.map((user) => (
          <tr
            key={user.id}
            onClick={() => onRowClick?.(user)}
            role="row"
            tabIndex={0}
            onKeyDown={(e) => e.key === 'Enter' && onRowClick?.(user)}
          >
            <td>{`${user.firstName} ${user.lastName}`}</td>
            <td>{user.email}</td>
            <td>
              <StatusBadge status={user.status} />
            </td>
            <td>{new Date(user.createdAt).toLocaleDateString()}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
};
```

### 1.2 TypeScript Types & Interfaces

#### Type Definition Guidelines

**Why Use Strict TypeScript?**
- Catch errors at compile time instead of runtime
- Self-documenting API contracts
- Enable IDE autocompletion and refactoring
- Enforce data shape consistency across layers
- Prevent invalid state representations

#### API Types (Request/Response)

```tsx
// api/types/user.ts

/**
 * API response type — matches backend contract exactly.
 * Never add frontend-only fields here.
 */
export interface User {
  readonly id: string;
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly phoneNumber: string | null;
  readonly status: UserStatus;
  readonly createdAt: string; // ISO 8601
  readonly updatedAt: string; // ISO 8601
}

export enum UserStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  SUSPENDED = 'SUSPENDED',
}

/**
 * Request DTO with validation constraints documented.
 * Frontend validation should mirror backend rules.
 */
export interface CreateUserRequest {
  email: string;       // Required, valid email, max 255 chars
  firstName: string;   // Required, 2–50 chars
  lastName: string;    // Required, 2–50 chars
  phoneNumber?: string; // Optional, E.164 format
}

export interface UpdateUserRequest {
  firstName?: string;
  lastName?: string;
  phoneNumber?: string;
  status?: UserStatus;
}
```

#### Shared / Common Types

```tsx
// types/common.ts

/**
 * Standard paginated API response shape.
 */
export interface PaginatedResponse<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  page: number;
  size: number;
  last: boolean;
}

export interface PaginationParams {
  page: number;
  size: number;
  sort?: string;
}

/**
 * Standard API error shape — matches backend ErrorResponse.
 */
export interface ApiError {
  timestamp: string;
  status: number;
  error: string;
  message: string;
  path: string;
  validationErrors?: ValidationError[];
}

export interface ValidationError {
  field: string;
  message: string;
  rejectedValue?: unknown;
}
```

#### Component Prop Types

```tsx
// ✅ CORRECT: Explicit prop interfaces
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  loading?: boolean;
  onClick: () => void;
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  variant,
  size = 'md',
  disabled = false,
  loading = false,
  onClick,
  children,
}) => { /* ... */ };

// ❌ WRONG: Using `any` or untyped props
export const Button = (props: any) => { /* ... */ };

// ❌ WRONG: Inline object types without interface
export const Button = (props: { variant: string; onClick: () => void }) => { /* ... */ };
```

### 1.3 Component Design Principles

#### Functional Components Only (Mandatory)

```tsx
// ✅ CORRECT: Functional component with hooks
export const UserProfile: React.FC<UserProfileProps> = ({ userId }) => {
  const { data: user, isLoading } = useUser(userId);

  if (isLoading) return <LoadingSpinner />;

  return (
    <div className="user-profile">
      <h2>{user?.firstName} {user?.lastName}</h2>
      <p>{user?.email}</p>
    </div>
  );
};

// ❌ WRONG: Class components (legacy pattern)
class UserProfile extends React.Component<UserProfileProps, UserProfileState> {
  componentDidMount() {
    this.fetchUser();
  }

  render() {
    return <div>{this.state.user?.name}</div>;
  }
}
```

#### Component Composition Over Inheritance

```tsx
// ✅ CORRECT: Composition pattern
interface CardProps {
  children: React.ReactNode;
  className?: string;
}

const Card: React.FC<CardProps> = ({ children, className }) => (
  <div className={`card ${className ?? ''}`}>{children}</div>
);

const CardHeader: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="card-header">{children}</div>
);

const CardBody: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="card-body">{children}</div>
);

// Usage — flexible composition
<Card>
  <CardHeader>
    <h3>User Details</h3>
  </CardHeader>
  <CardBody>
    <UserInfo user={user} />
  </CardBody>
</Card>

// ❌ WRONG: Prop-drilling to control layout
<Card
  headerTitle="User Details"
  showFooter={true}
  footerContent={<button>Save</button>}
  bodyComponent={<UserInfo user={user} />}
/>
```

#### Controlled vs. Uncontrolled Components

```tsx
/**
 * ✅ CORRECT: Controlled component — parent owns state
 */
interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

export const SearchInput: React.FC<SearchInputProps> = ({
  value,
  onChange,
  placeholder = 'Search...',
}) => (
  <input
    type="text"
    value={value}
    onChange={(e) => onChange(e.target.value)}
    placeholder={placeholder}
    aria-label={placeholder}
  />
);

/**
 * Uncontrolled component — only when integrating
 * with non-React libraries or for simple forms.
 * Use refs instead of state.
 */
export const FileUpload: React.FC<{ onUpload: (file: File) => void }> = ({ onUpload }) => {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleChange = () => {
    const file = inputRef.current?.files?.[0];
    if (file) onUpload(file);
  };

  return <input ref={inputRef} type="file" onChange={handleChange} />;
};
```

### 1.4 Naming Conventions

#### File & Directory Naming Standards

| Element | Convention | Example |
|---------|-----------|---------|
| Component files | PascalCase | `UserProfile.tsx` |
| Hook files | camelCase with `use` prefix | `useUsers.ts` |
| Utility files | camelCase | `formatDate.ts` |
| Type files | camelCase | `user.ts` |
| Test files | Match source + `.test` | `UserProfile.test.tsx` |
| Style files | Match component + `.module` | `UserProfile.module.css` |
| Constant files | camelCase | `apiRoutes.ts` |
| Context files | PascalCase + `Context` | `AuthContext.tsx` |
| Page files | PascalCase + `Page` | `UserListPage.tsx` |
| Store slices | camelCase + `Slice` | `userSlice.ts` |

#### Component & Variable Naming Standards

```tsx
// ✅ Component names: PascalCase
export const UserProfileCard: React.FC = () => {};
export const OrderSummaryTable: React.FC = () => {};

// ✅ Custom hooks: camelCase with "use" prefix
export function useAuth() {}
export function useUserPermissions() {}
export function useDebouncedSearch() {}

// ✅ Event handler props: on + Event
interface Props {
  onClick: () => void;
  onSubmit: (data: FormData) => void;
  onChange: (value: string) => void;
  onUserSelect: (user: User) => void;
}

// ✅ Event handler functions: handle + Event
const handleClick = () => {};
const handleSubmit = (data: FormData) => {};
const handleUserSelect = (user: User) => {};

// ✅ Boolean props/variables: is, has, can, should prefix
interface Props {
  isLoading: boolean;
  isDisabled: boolean;
  hasError: boolean;
  canEdit: boolean;
  shouldRefetch: boolean;
}

// ✅ Constants: UPPER_SNAKE_CASE
const MAX_RETRY_ATTEMPTS = 3;
const API_BASE_URL = '/api/v1';
const DEFAULT_PAGE_SIZE = 20;

// ✅ Enums: PascalCase with PascalCase members
enum UserStatus {
  Active = 'ACTIVE',
  Inactive = 'INACTIVE',
  Suspended = 'SUSPENDED',
}

// ❌ WRONG naming examples
export const userProfileCard = () => {};       // Components must be PascalCase
export function getAuth() {}                   // Hooks must start with "use"
const click_handler = () => {};               // Use camelCase
const isdata = true;                          // Unclear boolean name
```

### 1.5 State Management Guidelines

#### When to Use Each State Type

| State Type | Use When | Example |
|-----------|----------|---------|
| `useState` | Local component UI state | Form input, toggle, modal open/close |
| `useReducer` | Complex local state with multiple sub-values | Multi-step form, complex filter state |
| React Context | Shared state across a subtree (infrequent updates) | Theme, auth user, locale |
| TanStack Query | Server/async state (fetching, caching, syncing) | API data, pagination, search results |
| Redux/Zustand | Global client state (frequent cross-component updates) | Shopping cart, notification queue |

```tsx
// ✅ CORRECT: Server state with TanStack Query
function useUser(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => userApi.getById(userId),
    staleTime: 5 * 60 * 1000,
  });
}

// ✅ CORRECT: Local UI state with useState
function UserForm() {
  const [isEditing, setIsEditing] = useState(false);
  // ...
}

// ✅ CORRECT: Complex local state with useReducer
interface FormState {
  step: number;
  values: Record<string, string>;
  errors: Record<string, string>;
}

type FormAction =
  | { type: 'NEXT_STEP' }
  | { type: 'PREV_STEP' }
  | { type: 'SET_VALUE'; field: string; value: string }
  | { type: 'SET_ERROR'; field: string; error: string };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'NEXT_STEP':
      return { ...state, step: state.step + 1 };
    case 'PREV_STEP':
      return { ...state, step: state.step - 1 };
    case 'SET_VALUE':
      return { ...state, values: { ...state.values, [action.field]: action.value } };
    case 'SET_ERROR':
      return { ...state, errors: { ...state.errors, [action.field]: action.error } };
    default:
      return state;
  }
}

// ❌ WRONG: Using Redux for local form state
// ❌ WRONG: Using useState for server-fetched data without caching
// ❌ WRONG: Using React Context for frequently updating values (re-renders entire tree)
```

---

## 2. Architectural Patterns

### 2.1 SOLID Principles in React

#### 2.1.1 Single Responsibility Principle (SRP)

**Definition:** Each component, hook, or module should have one clear responsibility.

#### ❌ Violation Example

```tsx
/**
 * God component — fetches data, handles form, renders UI, manages state
 */
const UserPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [formData, setFormData] = useState({ name: '', email: '' });
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/v1/users')
      .then((res) => res.json())
      .then(setUsers)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleSubmit = async () => {
    // Inline validation
    if (!formData.email.includes('@')) {
      setError('Invalid email');
      return;
    }
    await fetch('/api/v1/users', {
      method: 'POST',
      body: JSON.stringify(formData),
    });
    // Re-fetch all users
    const res = await fetch('/api/v1/users');
    setUsers(await res.json());
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      <h1>Users</h1>
      <input
        value={formData.name}
        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
      />
      <input
        value={formData.email}
        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
      />
      <button onClick={handleSubmit}>Create</button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      <table>
        {users.map((u) => (
          <tr key={u.id}><td>{u.name}</td><td>{u.email}</td></tr>
        ))}
      </table>
    </div>
  );
};
```

#### ✅ Correct Implementation

```tsx
/**
 * SRP: Page component — composes feature components
 */
const UserListPage: React.FC = () => {
  const { users, isLoading, error, refetch } = useUsers();

  return (
    <PageLayout title="Users">
      <CreateUserForm onSuccess={refetch} />
      {error && <ErrorAlert message={error.message} />}
      {isLoading ? <LoadingSpinner /> : <UserTable users={users} />}
    </PageLayout>
  );
};

/**
 * SRP: Custom hook — data fetching and caching
 */
function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.list({ page: 0, size: 20 }),
  });
}

/**
 * SRP: Form component — user input and submission
 */
const CreateUserForm: React.FC<{ onSuccess: () => void }> = ({ onSuccess }) => {
  const createUser = useCreateUser();
  const { register, handleSubmit, formState: { errors } } = useForm<CreateUserRequest>();

  const onSubmit = async (data: CreateUserRequest) => {
    await createUser.mutateAsync(data);
    onSuccess();
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <FormField label="Name" error={errors.firstName?.message}>
        <input {...register('firstName', { required: 'Name is required' })} />
      </FormField>
      <FormField label="Email" error={errors.email?.message}>
        <input {...register('email', { required: 'Email is required' })} />
      </FormField>
      <Button type="submit" loading={createUser.isPending}>Create</Button>
    </form>
  );
};

/**
 * SRP: Display component — renders user table
 */
const UserTable: React.FC<{ users: User[] }> = ({ users }) => (
  <table role="table" aria-label="Users">
    <thead>
      <tr><th>Name</th><th>Email</th></tr>
    </thead>
    <tbody>
      {users.map((u) => (
        <tr key={u.id}><td>{u.firstName}</td><td>{u.email}</td></tr>
      ))}
    </tbody>
  </table>
);
```

#### 2.1.2 Open/Closed Principle (OCP)

**Definition:** Components should be open for extension but closed for modification.

#### ❌ Violation Example

```tsx
// Adding new notification types requires modifying this component
const NotificationBanner: React.FC<{ type: string; message: string }> = ({ type, message }) => {
  if (type === 'success') {
    return <div className="bg-green-500">{message}</div>;
  } else if (type === 'error') {
    return <div className="bg-red-500">{message}</div>;
  } else if (type === 'warning') {
    return <div className="bg-yellow-500">{message}</div>;
  }
  // Adding 'info' type means modifying this component
  return null;
};
```

#### ✅ Correct Implementation

```tsx
/**
 * OCP: Config-driven — extend via configuration, not modification
 */
const VARIANT_STYLES: Record<string, { className: string; icon: React.ReactNode }> = {
  success: { className: 'bg-green-500', icon: <CheckIcon /> },
  error:   { className: 'bg-red-500',   icon: <ErrorIcon /> },
  warning: { className: 'bg-yellow-500', icon: <WarningIcon /> },
  info:    { className: 'bg-blue-500',   icon: <InfoIcon /> },
};

interface NotificationBannerProps {
  variant: keyof typeof VARIANT_STYLES;
  message: string;
}

const NotificationBanner: React.FC<NotificationBannerProps> = ({ variant, message }) => {
  const style = VARIANT_STYLES[variant];
  return (
    <div className={style.className} role="alert">
      {style.icon}
      <span>{message}</span>
    </div>
  );
};

// Adding a new variant = adding to the config object, no component modification

/**
 * OCP: Render-prop / slot pattern — open for new layouts
 */
interface DataListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  emptyMessage?: string;
}

function DataList<T>({ items, renderItem, emptyMessage = 'No items' }: DataListProps<T>) {
  if (items.length === 0) return <p>{emptyMessage}</p>;
  return <ul>{items.map((item, i) => <li key={i}>{renderItem(item, i)}</li>)}</ul>;
}

// Usage — extend rendering without modifying DataList
<DataList
  items={users}
  renderItem={(user) => <UserCard user={user} />}
/>
```

#### 2.1.3 Liskov Substitution Principle (LSP)

**Definition:** A component that accepts a prop type should work correctly with any subtype of that type.

```tsx
/**
 * ✅ CORRECT: Generic components work with any compatible data shape
 */
interface HasId {
  id: string;
}

interface SelectableListProps<T extends HasId> {
  items: T[];
  selectedId: string | null;
  onSelect: (item: T) => void;
  renderLabel: (item: T) => string;
}

function SelectableList<T extends HasId>({
  items,
  selectedId,
  onSelect,
  renderLabel,
}: SelectableListProps<T>) {
  return (
    <ul role="listbox">
      {items.map((item) => (
        <li
          key={item.id}
          role="option"
          aria-selected={item.id === selectedId}
          onClick={() => onSelect(item)}
        >
          {renderLabel(item)}
        </li>
      ))}
    </ul>
  );
}

// Works with User, Order, Product — any type with id
<SelectableList
  items={users}
  selectedId={selectedUserId}
  onSelect={(user) => setSelectedUserId(user.id)}
  renderLabel={(user) => `${user.firstName} ${user.lastName}`}
/>
```

#### 2.1.4 Interface Segregation Principle (ISP)

**Definition:** Components should not be forced to accept props they don't use.

#### ❌ Violation Example

```tsx
// Fat prop interface forces every consumer to know about all options
interface UserCardProps {
  user: User;
  showEmail: boolean;
  showPhone: boolean;
  showAddress: boolean;
  showAvatar: boolean;
  editable: boolean;
  onEdit: (user: User) => void;
  onDelete: (userId: string) => void;
  showDeleteButton: boolean;
  compact: boolean;
}
```

#### ✅ Correct Implementation

```tsx
/**
 * ISP: Small, focused component interfaces
 */
interface UserAvatarProps {
  src: string;
  alt: string;
  size?: 'sm' | 'md' | 'lg';
}

interface UserInfoProps {
  firstName: string;
  lastName: string;
  email?: string;
}

interface UserActionsProps {
  onEdit: () => void;
  onDelete: () => void;
}

// Compose focussed components — consumers pick what they need
const UserCard: React.FC<{ user: User }> = ({ user }) => (
  <Card>
    <UserAvatar src={user.avatarUrl} alt={user.firstName} />
    <UserInfo firstName={user.firstName} lastName={user.lastName} email={user.email} />
  </Card>
);

const EditableUserCard: React.FC<{ user: User; onEdit: () => void; onDelete: () => void }> = ({
  user,
  onEdit,
  onDelete,
}) => (
  <Card>
    <UserAvatar src={user.avatarUrl} alt={user.firstName} />
    <UserInfo firstName={user.firstName} lastName={user.lastName} />
    <UserActions onEdit={onEdit} onDelete={onDelete} />
  </Card>
);
```

#### 2.1.5 Dependency Inversion Principle (DIP)

**Definition:** High-level components should not depend on low-level implementations. Both should depend on abstractions.

#### ❌ Violation Example

```tsx
// Component directly imports and calls fetch — tightly coupled to HTTP implementation
const UserList: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);

  useEffect(() => {
    fetch('/api/v1/users')
      .then((res) => res.json())
      .then(setUsers);
  }, []);

  return <ul>{users.map((u) => <li key={u.id}>{u.firstName}</li>)}</ul>;
};
```

#### ✅ Correct Implementation

```tsx
/**
 * DIP: Component depends on hook abstraction, not on fetch/axios directly
 */

// Abstraction: custom hook
function useUsers(): UseQueryResult<User[]> {
  return useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.list({ page: 0, size: 20 }).then((res) => res.content),
  });
}

// High-level component depends on abstraction (hook)
const UserList: React.FC = () => {
  const { data: users = [], isLoading } = useUsers();

  if (isLoading) return <LoadingSpinner />;
  return <ul>{users.map((u) => <li key={u.id}>{u.firstName}</li>)}</ul>;
};

/**
 * DIP: Context-based dependency injection for services
 */
interface AnalyticsService {
  trackEvent: (name: string, properties?: Record<string, unknown>) => void;
  trackPageView: (path: string) => void;
}

const AnalyticsContext = createContext<AnalyticsService | null>(null);

function useAnalytics(): AnalyticsService {
  const ctx = useContext(AnalyticsContext);
  if (!ctx) throw new Error('useAnalytics must be used within AnalyticsProvider');
  return ctx;
}

// Production provider — real analytics
const ProductionAnalyticsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const service: AnalyticsService = {
    trackEvent: (name, properties) => window.analytics.track(name, properties),
    trackPageView: (path) => window.analytics.page(path),
  };
  return <AnalyticsContext.Provider value={service}>{children}</AnalyticsContext.Provider>;
};

// Test provider — no-op implementation
const MockAnalyticsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const service: AnalyticsService = {
    trackEvent: vi.fn(),
    trackPageView: vi.fn(),
  };
  return <AnalyticsContext.Provider value={service}>{children}</AnalyticsContext.Provider>;
};
```

### 2.2 Common React Design Patterns

#### 2.2.1 Custom Hook Pattern

**Purpose:** Extract reusable stateful logic from components.

```tsx
/**
 * Custom hook: debounced search
 */
export function useDebouncedSearch<T>(
  searchFn: (query: string) => Promise<T[]>,
  delay: number = 300
) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<T[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  useEffect(() => {
    if (!query.trim()) {
      setResults([]);
      return;
    }

    const timeoutId = setTimeout(async () => {
      setIsSearching(true);
      try {
        const data = await searchFn(query);
        setResults(data);
      } finally {
        setIsSearching(false);
      }
    }, delay);

    return () => clearTimeout(timeoutId);
  }, [query, delay, searchFn]);

  return { query, setQuery, results, isSearching };
}

// Usage
const UserSearch: React.FC = () => {
  const { query, setQuery, results, isSearching } = useDebouncedSearch(
    (q) => userApi.search(q),
    300
  );

  return (
    <div>
      <SearchInput value={query} onChange={setQuery} />
      {isSearching ? <LoadingSpinner /> : <UserList users={results} />}
    </div>
  );
};
```

#### 2.2.2 Compound Component Pattern

**Purpose:** Components that work together, sharing implicit state.

```tsx
/**
 * Compound component: Tabs
 */
interface TabsContextType {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const TabsContext = createContext<TabsContextType | null>(null);

function useTabs(): TabsContextType {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error('Tab components must be used within <Tabs>');
  return ctx;
}

interface TabsProps {
  defaultTab: string;
  children: React.ReactNode;
  onChange?: (tab: string) => void;
}

const Tabs: React.FC<TabsProps> & {
  List: typeof TabList;
  Tab: typeof Tab;
  Panels: typeof TabPanels;
  Panel: typeof TabPanel;
} = ({ defaultTab, children, onChange }) => {
  const [activeTab, setActiveTab] = useState(defaultTab);

  const handleSetActive = useCallback(
    (tab: string) => {
      setActiveTab(tab);
      onChange?.(tab);
    },
    [onChange]
  );

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab: handleSetActive }}>
      <div role="tablist">{children}</div>
    </TabsContext.Provider>
  );
};

const TabList: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div role="tablist">{children}</div>
);

const Tab: React.FC<{ id: string; children: React.ReactNode }> = ({ id, children }) => {
  const { activeTab, setActiveTab } = useTabs();
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
};

const TabPanels: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div>{children}</div>
);

const TabPanel: React.FC<{ id: string; children: React.ReactNode }> = ({ id, children }) => {
  const { activeTab } = useTabs();
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
};

Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panels = TabPanels;
Tabs.Panel = TabPanel;

// Usage
<Tabs defaultTab="profile">
  <Tabs.List>
    <Tabs.Tab id="profile">Profile</Tabs.Tab>
    <Tabs.Tab id="settings">Settings</Tabs.Tab>
    <Tabs.Tab id="billing">Billing</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panels>
    <Tabs.Panel id="profile"><ProfileSection /></Tabs.Panel>
    <Tabs.Panel id="settings"><SettingsSection /></Tabs.Panel>
    <Tabs.Panel id="billing"><BillingSection /></Tabs.Panel>
  </Tabs.Panels>
</Tabs>
```

#### 2.2.3 Higher-Order Component (HOC) Pattern

**Purpose:** Enhance a component with cross-cutting behavior.

```tsx
/**
 * HOC: withAuth — restricts access to authenticated users
 */
function withAuth<P extends object>(
  WrappedComponent: React.ComponentType<P>
): React.FC<P> {
  const AuthenticatedComponent: React.FC<P> = (props) => {
    const { isAuthenticated, isLoading } = useAuth();
    const navigate = useNavigate();

    useEffect(() => {
      if (!isLoading && !isAuthenticated) {
        navigate('/login', { replace: true });
      }
    }, [isAuthenticated, isLoading, navigate]);

    if (isLoading) return <LoadingSpinner />;
    if (!isAuthenticated) return null;

    return <WrappedComponent {...props} />;
  };

  AuthenticatedComponent.displayName = `withAuth(${
    WrappedComponent.displayName || WrappedComponent.name || 'Component'
  })`;

  return AuthenticatedComponent;
}

// Usage
const ProtectedDashboard = withAuth(Dashboard);

/**
 * Prefer custom hooks over HOCs in modern React.
 * Use HOCs only when you need to wrap component rendering (e.g., route guards).
 */
```

#### 2.2.4 Render Props Pattern

**Purpose:** Share behavior via a function-as-child or render prop.

```tsx
/**
 * Render prop: MouseTracker
 */
interface MousePosition {
  x: number;
  y: number;
}

interface MouseTrackerProps {
  render: (position: MousePosition) => React.ReactNode;
}

const MouseTracker: React.FC<MouseTrackerProps> = ({ render }) => {
  const [position, setPosition] = useState<MousePosition>({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setPosition({ x: e.clientX, y: e.clientY });
    };
    window.addEventListener('mousemove', handleMouseMove);
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  return <>{render(position)}</>;
};

// Usage
<MouseTracker
  render={({ x, y }) => (
    <div>Mouse is at ({x}, {y})</div>
  )}
/>

/**
 * Prefer custom hooks over render props for most use cases.
 * function useMousePosition(): MousePosition { ... }
 */
```

#### 2.2.5 Provider Pattern (Dependency Injection)

**Purpose:** Provide services/configuration/state to a component subtree without prop drilling.

```tsx
/**
 * Feature flag provider — inject feature flags into any subtree
 */
interface FeatureFlags {
  enableDarkMode: boolean;
  enableNewCheckout: boolean;
  enableBetaFeatures: boolean;
}

const FeatureFlagContext = createContext<FeatureFlags>({
  enableDarkMode: false,
  enableNewCheckout: false,
  enableBetaFeatures: false,
});

export const useFeatureFlags = () => useContext(FeatureFlagContext);

export const FeatureFlagProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { data: flags, isLoading } = useQuery({
    queryKey: ['featureFlags'],
    queryFn: () => featureFlagApi.getFlags(),
    staleTime: 10 * 60 * 1000,
  });

  if (isLoading) return <LoadingSpinner />;

  return (
    <FeatureFlagContext.Provider value={flags!}>
      {children}
    </FeatureFlagContext.Provider>
  );
};

// Usage in component
const CheckoutButton: React.FC = () => {
  const { enableNewCheckout } = useFeatureFlags();
  
  return enableNewCheckout ? <NewCheckoutFlow /> : <LegacyCheckoutFlow />;
};
```

### 2.3 Form Handling Best Practices

#### Use React Hook Form + Zod for Validation

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

/**
 * Zod schema — single source of truth for validation rules.
 * Must mirror backend validation constraints.
 */
const createUserSchema = z.object({
  email: z
    .string()
    .min(1, 'Email is required')
    .email('Email must be valid')
    .max(255, 'Email must not exceed 255 characters'),
  firstName: z
    .string()
    .min(2, 'First name must be at least 2 characters')
    .max(50, 'First name must not exceed 50 characters')
    .regex(/^[a-zA-Z\s'-]+$/, 'First name contains invalid characters'),
  lastName: z
    .string()
    .min(2, 'Last name must be at least 2 characters')
    .max(50, 'Last name must not exceed 50 characters')
    .regex(/^[a-zA-Z\s'-]+$/, 'Last name contains invalid characters'),
  phoneNumber: z
    .string()
    .regex(/^\+?[1-9]\d{1,14}$/, 'Phone number must be in E.164 format')
    .optional()
    .or(z.literal('')),
});

type CreateUserFormData = z.infer<typeof createUserSchema>;

/**
 * Form component with validation
 */
const CreateUserForm: React.FC<{ onSuccess: () => void }> = ({ onSuccess }) => {
  const createUserMutation = useCreateUser();

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<CreateUserFormData>({
    resolver: zodResolver(createUserSchema),
    defaultValues: {
      email: '',
      firstName: '',
      lastName: '',
      phoneNumber: '',
    },
  });

  const onSubmit = async (data: CreateUserFormData) => {
    try {
      await createUserMutation.mutateAsync(data);
      reset();
      onSuccess();
    } catch (error) {
      if (isApiError(error) && error.validationErrors) {
        // Map server validation errors to form fields
        error.validationErrors.forEach((ve) => {
          setError(ve.field as keyof CreateUserFormData, {
            type: 'server',
            message: ve.message,
          });
        });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <FormField label="Email" error={errors.email?.message} required>
        <input
          type="email"
          {...register('email')}
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined}
        />
      </FormField>

      <FormField label="First Name" error={errors.firstName?.message} required>
        <input type="text" {...register('firstName')} aria-invalid={!!errors.firstName} />
      </FormField>

      <FormField label="Last Name" error={errors.lastName?.message} required>
        <input type="text" {...register('lastName')} aria-invalid={!!errors.lastName} />
      </FormField>

      <FormField label="Phone Number" error={errors.phoneNumber?.message}>
        <input type="tel" {...register('phoneNumber')} aria-invalid={!!errors.phoneNumber} />
      </FormField>

      <Button type="submit" loading={isSubmitting} disabled={isSubmitting}>
        Create User
      </Button>
    </form>
  );
};
```

### 2.4 Routing Best Practices

```tsx
/**
 * Route configuration with lazy loading and guards
 */
import { lazy, Suspense } from 'react';
import { createBrowserRouter, RouterProvider, Navigate, Outlet } from 'react-router-dom';

// Lazy-loaded page components
const UserListPage = lazy(() => import('@/features/users/pages/UserListPage'));
const UserDetailPage = lazy(() => import('@/features/users/pages/UserDetailPage'));
const OrderListPage = lazy(() => import('@/features/orders/pages/OrderListPage'));
const LoginPage = lazy(() => import('@/features/auth/pages/LoginPage'));
const NotFoundPage = lazy(() => import('@/pages/NotFoundPage'));

/**
 * Route guard component — protects child routes
 */
const ProtectedRoute: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) return <LoadingSpinner />;
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Outlet />
    </Suspense>
  );
};

/**
 * Role-based route guard
 */
const RoleGuard: React.FC<{ allowedRoles: string[] }> = ({ allowedRoles }) => {
  const { user } = useAuth();

  if (!user || !allowedRoles.some((role) => user.roles.includes(role))) {
    return <Navigate to="/unauthorized" replace />;
  }

  return <Outlet />;
};

/**
 * Application router
 */
const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <AppLayout />,
        children: [
          { path: '/', element: <Navigate to="/users" replace /> },
          { path: '/users', element: <UserListPage /> },
          { path: '/users/:userId', element: <UserDetailPage /> },
          { path: '/orders', element: <OrderListPage /> },
          {
            element: <RoleGuard allowedRoles={['ADMIN']} />,
            children: [
              { path: '/admin/settings', element: <AdminSettingsPage /> },
            ],
          },
        ],
      },
    ],
  },
  { path: '*', element: <NotFoundPage /> },
]);

export const App: React.FC = () => <RouterProvider router={router} />;
```

### 2.5 Error Handling

#### Global Error Boundary

```tsx
/**
 * Error Boundary — catches rendering errors in the component tree.
 * Must be a class component (React limitation).
 */
interface ErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
    // Log error to monitoring service
    logger.error('Unhandled React error', { error, componentStack: errorInfo.componentStack });
    this.props.onError?.(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback ?? (
          <div role="alert">
            <h2>Something went wrong</h2>
            <p>Please refresh the page or contact support.</p>
            <button onClick={() => this.setState({ hasError: false, error: null })}>
              Try Again
            </button>
          </div>
        )
      );
    }

    return this.props.children;
  }
}
```

#### API Error Handling

```tsx
/**
 * Standard API error handling with TanStack Query
 */
export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateUserRequest) => userApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      toast.success('User created successfully');
    },
    onError: (error: ApiError) => {
      if (error.status === 409) {
        toast.error('A user with this email already exists');
      } else if (error.status === 422) {
        toast.error(error.message);
      } else {
        toast.error('An unexpected error occurred. Please try again.');
        logger.error('Create user failed', { error });
      }
    },
  });
}

/**
 * API error type guard
 */
export function isApiError(error: unknown): error is ApiError {
  return (
    typeof error === 'object' &&
    error !== null &&
    'status' in error &&
    'message' in error
  );
}
```

### 2.6 Anti-Patterns to Avoid

#### 2.6.1 Prop Drilling

**Problem:** Passing props through multiple intermediate components that don't use them.

```tsx
// ❌ Anti-Pattern: Prop drilling through 4 levels
const App = () => {
  const [user, setUser] = useState<User | null>(null);
  return <Layout user={user}><Dashboard user={user}><Sidebar user={user} /></Dashboard></Layout>;
};

// ✅ Use Context or hooks
const UserContext = createContext<User | null>(null);
const useCurrentUser = () => useContext(UserContext);

const App = () => {
  const [user] = useState<User | null>(null);
  return (
    <UserContext.Provider value={user}>
      <Layout><Dashboard><Sidebar /></Dashboard></Layout>
    </UserContext.Provider>
  );
};

const Sidebar = () => {
  const user = useCurrentUser();
  return <span>{user?.firstName}</span>;
};
```

#### 2.6.2 Unnecessary useEffect

**Problem:** Using useEffect for logic that can be computed during render.

```tsx
// ❌ Anti-Pattern: Derived state in useEffect
const [items, setItems] = useState<Item[]>([]);
const [filteredItems, setFilteredItems] = useState<Item[]>([]);
const [filter, setFilter] = useState('');

useEffect(() => {
  setFilteredItems(items.filter((item) => item.name.includes(filter)));
}, [items, filter]);

// ✅ Derive during render — no useEffect, no extra state
const [items, setItems] = useState<Item[]>([]);
const [filter, setFilter] = useState('');
const filteredItems = useMemo(
  () => items.filter((item) => item.name.includes(filter)),
  [items, filter]
);
```

#### 2.6.3 Giant Component Files

**Problem:** Components exceeding 200–300 lines, mixing multiple concerns.

```tsx
// ❌ Anti-Pattern: 500+ line component with inline API calls, validation, rendering
// ✅ Split into:
//    - Page component (composition)
//    - Custom hooks (data/logic)
//    - Sub-components (UI)
//    - Validation schemas (Zod)
```

#### 2.6.4 Direct DOM Manipulation

**Problem:** Using `document.querySelector` or `innerHTML` instead of React state.

```tsx
// ❌ Anti-Pattern: Direct DOM manipulation
useEffect(() => {
  document.getElementById('status')!.innerHTML = status;
}, [status]);

// ✅ Use React state and JSX
return <span id="status">{status}</span>;
```

#### 2.6.5 Index as Key in Dynamic Lists

**Problem:** Using array index as key for lists that can be reordered, filtered, or mutated.

```tsx
// ❌ Anti-Pattern: Index as key — causes bugs on reorder/delete
{items.map((item, index) => <ListItem key={index} item={item} />)}

// ✅ Use stable unique identifier
{items.map((item) => <ListItem key={item.id} item={item} />)}
```

---

## 3. Security Standards

### 3.1 Application Security

#### 3.1.1 Cross-Site Scripting (XSS) Prevention

```tsx
/**
 * React automatically escapes JSX expressions.
 * ✅ Safe by default — user input is escaped
 */
const UserGreeting: React.FC<{ name: string }> = ({ name }) => (
  <h1>Hello, {name}</h1> // Safe: React escapes `name`
);

/**
 * ❌ NEVER use dangerouslySetInnerHTML with untrusted data
 */
// ❌ WRONG: XSS vulnerability
const UnsafeComponent: React.FC<{ html: string }> = ({ html }) => (
  <div dangerouslySetInnerHTML={{ __html: html }} /> // XSS risk!
);

/**
 * ✅ If you must render HTML, sanitize it first with DOMPurify
 */
import DOMPurify from 'dompurify';

const SafeHtmlRenderer: React.FC<{ html: string }> = ({ html }) => {
  const sanitizedHtml = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li', 'a'],
    ALLOWED_ATTR: ['href', 'target', 'rel'],
  });

  return <div dangerouslySetInnerHTML={{ __html: sanitizedHtml }} />;
};

/**
 * ✅ Sanitize URL schemes to prevent JavaScript injection
 */
function isSafeUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ['http:', 'https:', 'mailto:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

const SafeLink: React.FC<{ href: string; children: React.ReactNode }> = ({ href, children }) => {
  if (!isSafeUrl(href)) {
    return <span>{children}</span>;
  }
  return (
    <a href={href} target="_blank" rel="noopener noreferrer">
      {children}
    </a>
  );
};
```

#### 3.1.2 Authentication & Token Management

```tsx
/**
 * ✅ Store tokens securely:
 * - Access token: in-memory (React state/context) — never localStorage
 * - Refresh token: httpOnly cookie (set by server)
 *
 * ❌ NEVER store tokens in:
 * - localStorage (XSS accessible)
 * - sessionStorage (XSS accessible)
 * - Non-httpOnly cookies (XSS accessible)
 */

interface AuthState {
  user: AuthUser | null;
  accessToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

const AuthContext = createContext<AuthState & {
  login: (credentials: LoginRequest) => Promise<void>;
  logout: () => Promise<void>;
  refreshToken: () => Promise<string>;
} | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AuthState>({
    user: null,
    accessToken: null,
    isAuthenticated: false,
    isLoading: true,
  });

  const login = useCallback(async (credentials: LoginRequest) => {
    const response = await authApi.login(credentials);
    // Access token in memory only — refresh token comes via httpOnly cookie
    setState({
      user: response.user,
      accessToken: response.accessToken,
      isAuthenticated: true,
      isLoading: false,
    });
  }, []);

  const logout = useCallback(async () => {
    await authApi.logout(); // Server clears httpOnly cookie
    setState({ user: null, accessToken: null, isAuthenticated: false, isLoading: false });
  }, []);

  const refreshToken = useCallback(async () => {
    const response = await authApi.refresh(); // Uses httpOnly cookie
    setState((prev) => ({ ...prev, accessToken: response.accessToken }));
    return response.accessToken;
  }, []);

  // Attempt silent refresh on mount
  useEffect(() => {
    refreshToken()
      .catch(() => setState((prev) => ({ ...prev, isLoading: false })));
  }, [refreshToken]);

  return (
    <AuthContext.Provider value={{ ...state, login, logout, refreshToken }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};
```

#### 3.1.3 CSRF Protection

```tsx
/**
 * ✅ CSRF protection for cookie-based auth:
 * 1. Backend sets CSRF token in a response header or cookie
 * 2. Frontend reads it and includes in subsequent requests
 */

// api/clients/httpClient.ts — include CSRF token
httpClient.interceptors.request.use((config) => {
  const csrfToken = getCsrfToken();
  if (csrfToken && config.headers) {
    config.headers['X-CSRF-Token'] = csrfToken;
  }
  return config;
});

function getCsrfToken(): string | null {
  // Read from meta tag (server-rendered)
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta?.getAttribute('content') ?? null;
}
```

#### 3.1.4 Content Security Policy (CSP)

```tsx
/**
 * ✅ CSP should be set by the server via HTTP headers.
 * React apps should be compatible with strict CSP:
 * - No inline styles via style="" (use CSS-in-JS with nonce or CSS Modules)
 * - No eval() or new Function()
 * - No inline event handlers (onClick in JSX is safe — React uses event delegation)
 *
 * Example CSP header (configured in server/CDN):
 * Content-Security-Policy:
 *   default-src 'self';
 *   script-src 'self' 'nonce-{RANDOM}';
 *   style-src 'self' 'nonce-{RANDOM}';
 *   img-src 'self' data: https:;
 *   connect-src 'self' https://api.example.com;
 *   frame-ancestors 'none';
 *   base-uri 'self';
 *   form-action 'self';
 */
```

#### 3.1.5 Sensitive Data Handling

```tsx
/**
 * ✅ NEVER log or expose sensitive data in the frontend
 */

// ❌ WRONG: Logging sensitive data
console.log('User password:', password);
console.log('Token:', accessToken);

// ✅ CORRECT: Masked logging
logger.info('Login attempt', { email: maskEmail(email) });

// ❌ WRONG: Storing sensitive data in state accessible via DevTools
const [creditCard, setCreditCard] = useState(creditCardNumber);

// ✅ CORRECT: Process sensitive data and clear immediately
const handlePayment = async (cardNumber: string) => {
  const token = await paymentApi.tokenize(cardNumber);
  // cardNumber is never stored in state — only the token
  await paymentApi.charge(token);
};

/**
 * ✅ Mask sensitive values in UI
 */
function maskEmail(email: string): string {
  const [user, domain] = email.split('@');
  if (!domain) return '***';
  const maskedUser = user.length > 2
    ? `${user[0]}${'*'.repeat(user.length - 2)}${user[user.length - 1]}`
    : '**';
  return `${maskedUser}@${domain}`;
}

function maskCardNumber(card: string): string {
  return `****-****-****-${card.slice(-4)}`;
}
```

#### 3.1.6 Dependency Security

```jsonc
// package.json — security scripts
{
  "scripts": {
    "audit": "npm audit --production",
    "audit:fix": "npm audit fix",
    "deps:check": "npx npm-check-updates"
  }
}
```

**Mandatory Practices:**
- Run `npm audit` in CI pipeline; fail build on high/critical vulnerabilities
- Pin exact dependency versions (use `package-lock.json`)
- Regularly update dependencies (minimum monthly)
- Use `npm audit signatures` to verify package provenance
- Do not install packages with `--ignore-scripts` disabled in untrusted environments

### 3.2 Environment Configuration

```tsx
/**
 * ✅ Use Vite environment variables (VITE_ prefix)
 * ❌ NEVER put secrets in frontend environment variables —
 *    they are bundled into the client-side JavaScript!
 */

// config/env.ts
interface AppConfig {
  apiBaseUrl: string;
  appName: string;
  environment: 'development' | 'staging' | 'production';
  featureFlagServiceUrl: string;
  sentryDsn: string;
}

export const appConfig: AppConfig = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080',
  appName: import.meta.env.VITE_APP_NAME ?? 'AA Cargo App',
  environment: (import.meta.env.VITE_ENV as AppConfig['environment']) ?? 'development',
  featureFlagServiceUrl: import.meta.env.VITE_FEATURE_FLAG_URL ?? '',
  sentryDsn: import.meta.env.VITE_SENTRY_DSN ?? '',
};

/**
 * ✅ Validate config at startup
 */
function validateConfig(config: AppConfig): void {
  if (!config.apiBaseUrl) {
    throw new Error('VITE_API_BASE_URL is required');
  }
  if (config.environment === 'production' && !config.sentryDsn) {
    console.warn('Sentry DSN is not configured for production');
  }
}

validateConfig(appConfig);
```

### 3.3 Input Validation & Sanitization

```tsx
/**
 * ✅ Validate all user inputs on the client AND server.
 * Client validation is for UX; server validation is for security.
 */

// Zod schemas — reusable validation rules
export const emailSchema = z
  .string()
  .min(1, 'Email is required')
  .email('Invalid email format')
  .max(255, 'Email too long')
  .transform((val) => val.trim().toLowerCase());

export const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(100, 'Password must not exceed 100 characters')
  .regex(/[0-9]/, 'Must contain at least one digit')
  .regex(/[a-z]/, 'Must contain at least one lowercase letter')
  .regex(/[A-Z]/, 'Must contain at least one uppercase letter')
  .regex(/[@#$%^&+=!]/, 'Must contain at least one special character');

/**
 * ✅ Sanitize file names for upload
 */
function sanitizeFileName(name: string): string {
  return name
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/\.{2,}/g, '.');
}

/**
 * ✅ Validate and sanitize URL parameters
 */
function sanitizeSearchQuery(query: string): string {
  return query
    .trim()
    .slice(0, 200) // Limit length
    .replace(/[<>]/g, ''); // Remove HTML brackets
}
```

---

## 4. Performance and Resiliency

### 4.0 Required Guidelines (Normative)

| # | Guideline | Priority |
|---|-----------|----------|
| 1 | Code-split route-level pages with `React.lazy` | **MANDATORY** |
| 2 | Use `React.memo` only after profiling proves re-render cost | **RECOMMENDED** |
| 3 | Use `useMemo`/`useCallback` for expensive computations and stable references | **MANDATORY** |
| 4 | Implement image optimization (lazy loading, WebP, srcset) | **MANDATORY** |
| 5 | Use TanStack Query (or equivalent) for server state caching | **MANDATORY** |
| 6 | Set `staleTime` and cache policies for all queries | **MANDATORY** |
| 7 | Bundle size must not exceed 250KB gzipped for initial load | **MANDATORY** |
| 8 | Lighthouse Performance score >= 90 in CI | **RECOMMENDED** |
| 9 | Use Web Vitals monitoring (LCP, FID, CLS) | **MANDATORY** |
| 10 | Implement retry logic with exponential backoff for API calls | **MANDATORY** |

### 4.1 Rendering Optimization

#### React.memo for Expensive Components

```tsx
/**
 * ✅ Use React.memo when:
 * - Component renders often with same props
 * - Component rendering is expensive (large lists, charts)
 * - Parent re-renders frequently but child props don't change
 *
 * ❌ Do NOT use React.memo for:
 * - Simple, lightweight components
 * - Components that almost always receive new props
 */
const UserCard = React.memo<UserCardProps>(({ user, onClick }) => {
  return (
    <div className="user-card" onClick={() => onClick(user.id)}>
      <img src={user.avatarUrl} alt={user.firstName} loading="lazy" />
      <h3>{user.firstName} {user.lastName}</h3>
      <p>{user.email}</p>
    </div>
  );
});
UserCard.displayName = 'UserCard';

/**
 * ✅ Custom equality for complex props
 */
const OrderRow = React.memo<OrderRowProps>(
  ({ order, onSelect }) => {
    return (
      <tr onClick={() => onSelect(order.id)}>
        <td>{order.orderNumber}</td>
        <td>{order.status}</td>
        <td>{order.totalAmount}</td>
      </tr>
    );
  },
  (prevProps, nextProps) =>
    prevProps.order.id === nextProps.order.id &&
    prevProps.order.status === nextProps.order.status
);
```

#### useMemo and useCallback

```tsx
/**
 * ✅ useMemo: Memoize expensive computations
 */
const UserDashboard: React.FC<{ users: User[]; filter: string }> = ({ users, filter }) => {
  // Expensive filter — only recompute when users or filter changes
  const filteredUsers = useMemo(
    () => users.filter((u) => u.firstName.toLowerCase().includes(filter.toLowerCase())),
    [users, filter]
  );

  // Expensive aggregation
  const stats = useMemo(() => ({
    total: users.length,
    active: users.filter((u) => u.status === 'ACTIVE').length,
    inactive: users.filter((u) => u.status === 'INACTIVE').length,
  }), [users]);

  return (
    <>
      <StatsBar stats={stats} />
      <UserList users={filteredUsers} />
    </>
  );
};

/**
 * ✅ useCallback: Stabilize function references for child components
 */
const UserListPage: React.FC = () => {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // Stable reference — prevents UserCard re-renders from parent state changes
  const handleSelect = useCallback((userId: string) => {
    setSelectedId(userId);
  }, []);

  return <UserList onUserSelect={handleSelect} />;
};
```

### 4.2 Code Splitting & Lazy Loading

```tsx
/**
 * ✅ Route-level code splitting (MANDATORY)
 */
const UserListPage = lazy(() => import('@/features/users/pages/UserListPage'));
const OrderListPage = lazy(() => import('@/features/orders/pages/OrderListPage'));
const AdminDashboard = lazy(() => import('@/features/admin/pages/AdminDashboard'));

/**
 * ✅ Component-level code splitting for heavy components
 */
const HeavyChart = lazy(() => import('@/components/charts/HeavyChart'));
const RichTextEditor = lazy(() => import('@/components/editor/RichTextEditor'));

/**
 * ✅ Suspense boundary with fallback
 */
const AppRoutes: React.FC = () => (
  <Suspense fallback={<PageSkeleton />}>
    <Routes>
      <Route path="/users" element={<UserListPage />} />
      <Route path="/orders" element={<OrderListPage />} />
    </Routes>
  </Suspense>
);

/**
 * ✅ Image lazy loading
 */
const Avatar: React.FC<{ src: string; alt: string }> = ({ src, alt }) => (
  <img
    src={src}
    alt={alt}
    loading="lazy"
    decoding="async"
    width={48}
    height={48}
  />
);
```

### 4.3 API Resilience Patterns

#### Retry with Exponential Backoff

```tsx
/**
 * TanStack Query retry configuration
 */
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
      staleTime: 5 * 60 * 1000,      // 5 minutes
      gcTime: 10 * 60 * 1000,         // 10 minutes garbage collection
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: 1,
      retryDelay: 1000,
    },
  },
});
```

#### Optimistic Updates

```tsx
/**
 * ✅ Optimistic update — update UI immediately, rollback on error
 */
function useDeleteUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (userId: string) => userApi.delete(userId),
    onMutate: async (userId) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['users'] });

      // Snapshot previous value
      const previousUsers = queryClient.getQueryData<User[]>(['users']);

      // Optimistically remove user
      queryClient.setQueryData<User[]>(['users'], (old) =>
        old?.filter((u) => u.id !== userId) ?? []
      );

      return { previousUsers };
    },
    onError: (_error, _userId, context) => {
      // Rollback to snapshot
      if (context?.previousUsers) {
        queryClient.setQueryData(['users'], context.previousUsers);
      }
      toast.error('Failed to delete user');
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

#### Offline Support

```tsx
/**
 * ✅ Online/offline detection for graceful degradation
 */
export function useOnlineStatus() {
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return isOnline;
}

// Usage
const App: React.FC = () => {
  const isOnline = useOnlineStatus();

  return (
    <>
      {!isOnline && (
        <div role="alert" className="offline-banner">
          You are offline. Some features may be unavailable.
        </div>
      )}
      <AppRoutes />
    </>
  );
};
```

### 4.4 Bundle Size Optimization

```tsx
/**
 * ✅ Tree-shakable imports
 */
// ✅ CORRECT: Named imports — tree-shakable
import { format, parseISO } from 'date-fns';
import { debounce } from 'lodash-es';

// ❌ WRONG: Default imports — entire library bundled
import _ from 'lodash';
import moment from 'moment';

/**
 * ✅ Analyze bundle with visualizer
 * vite.config.ts:
 */
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    react(),
    visualizer({ open: true, gzipSize: true }),
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          query: ['@tanstack/react-query'],
        },
      },
    },
  },
});
```

---

## 5. Monitoring & Logging

### 5.0 Required Guidelines (Normative)

| # | Guideline | Priority |
|---|-----------|----------|
| 1 | Capture Web Vitals (LCP, FID, CLS, TTFB, INP) | **MANDATORY** |
| 2 | Integrate error tracking (Sentry or equivalent) | **MANDATORY** |
| 3 | Implement structured client-side logging | **MANDATORY** |
| 4 | No `console.log` in production builds | **MANDATORY** |
| 5 | Track API call performance and error rates | **MANDATORY** |
| 6 | Alerts for error rate spikes | **RECOMMENDED** |

### 5.1 Web Vitals Monitoring

```tsx
/**
 * ✅ Track Core Web Vitals
 */
import { onCLS, onFID, onLCP, onTTFB, onINP, type Metric } from 'web-vitals';

function reportWebVital(metric: Metric): void {
  // Send to analytics/monitoring service
  logger.info('web-vital', {
    name: metric.name,
    value: metric.value,
    rating: metric.rating, // 'good' | 'needs-improvement' | 'poor'
    delta: metric.delta,
    id: metric.id,
    navigationType: metric.navigationType,
  });
}

// Initialize in main.tsx
onCLS(reportWebVital);
onFID(reportWebVital);
onLCP(reportWebVital);
onTTFB(reportWebVital);
onINP(reportWebVital);
```

### 5.2 Structured Logging

```tsx
/**
 * ✅ Structured logger — replaces console.log
 */

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  context?: Record<string, unknown>;
  correlationId?: string;
}

class Logger {
  private static instance: Logger;
  private minLevel: LogLevel;

  private constructor() {
    this.minLevel = appConfig.environment === 'production' ? 'warn' : 'debug';
  }

  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  private shouldLog(level: LogLevel): boolean {
    const levels: LogLevel[] = ['debug', 'info', 'warn', 'error'];
    return levels.indexOf(level) >= levels.indexOf(this.minLevel);
  }

  private log(level: LogLevel, message: string, context?: Record<string, unknown>): void {
    if (!this.shouldLog(level)) return;

    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      context,
    };

    // In development, log to console
    if (appConfig.environment !== 'production') {
      const consoleFn = level === 'error' ? console.error : level === 'warn' ? console.warn : console.log;
      consoleFn(`[${entry.level.toUpperCase()}] ${entry.message}`, entry.context ?? '');
    }

    // In production, send to monitoring service
    if (appConfig.environment === 'production') {
      this.sendToMonitoring(entry);
    }
  }

  debug(message: string, context?: Record<string, unknown>): void { this.log('debug', message, context); }
  info(message: string, context?: Record<string, unknown>): void { this.log('info', message, context); }
  warn(message: string, context?: Record<string, unknown>): void { this.log('warn', message, context); }
  error(message: string, context?: Record<string, unknown>): void { this.log('error', message, context); }

  private sendToMonitoring(entry: LogEntry): void {
    // Integration with Sentry, Datadog, or custom logging service
    if (entry.level === 'error') {
      Sentry.captureMessage(entry.message, {
        level: 'error',
        extra: entry.context,
      });
    }
  }
}

export const logger = Logger.getInstance();

// Usage
logger.info('User login successful', { userId: user.id });
logger.error('API call failed', { endpoint: '/api/v1/users', status: 500 });
```

### 5.3 Error Tracking Integration

```tsx
/**
 * ✅ Sentry integration for error monitoring
 */
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: appConfig.sentryDsn,
  environment: appConfig.environment,
  release: import.meta.env.VITE_APP_VERSION,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  tracesSampleRate: appConfig.environment === 'production' ? 0.1 : 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  beforeSend(event) {
    // Scrub sensitive data before sending to Sentry
    if (event.request?.headers) {
      delete event.request.headers['Authorization'];
    }
    return event;
  },
});

/**
 * ✅ Wrap routes with Sentry error boundary
 */
const SentryRoutes = Sentry.withSentryReactRouterV6Routing(Routes);
```

### 5.4 API Performance Tracking

```tsx
/**
 * ✅ Axios interceptor for API call duration tracking
 */
httpClient.interceptors.request.use((config) => {
  (config as any).__startTime = performance.now();
  return config;
});

httpClient.interceptors.response.use(
  (response) => {
    const duration = performance.now() - (response.config as any).__startTime;
    logger.info('API call succeeded', {
      method: response.config.method?.toUpperCase(),
      url: response.config.url,
      status: response.status,
      durationMs: Math.round(duration),
    });
    return response;
  },
  (error) => {
    if (error.config) {
      const duration = performance.now() - (error.config as any).__startTime;
      logger.error('API call failed', {
        method: error.config.method?.toUpperCase(),
        url: error.config.url,
        status: error.response?.status,
        durationMs: Math.round(duration),
        message: error.message,
      });
    }
    return Promise.reject(error);
  }
);
```

---

## 6. Testing Standards

### 6.0 Test Coverage Requirements (NON-NEGOTIABLE)

| Metric | Minimum | Target |
|--------|---------|--------|
| Statement coverage | 80% | 90% |
| Branch coverage | 75% | 85% |
| Function coverage | 80% | 90% |
| Critical path coverage | 100% | 100% |

### 6.1 Test Pyramid

```
         /  E2E Tests  \          <- Few: Cypress/Playwright (critical user flows)
        /  Integration   \        <- Some: Component + API integration
       /  Component Tests \       <- Many: React Testing Library
      /    Unit Tests      \      <- Most: Vitest (hooks, utils, services)
     /________________________\
```

- **Unit Tests:** Pure functions, custom hooks, utility functions, reducers, Zod schemas
- **Component Tests:** Component rendering, user interactions, accessibility
- **Integration Tests:** Feature flows, page-level interactions with mocked APIs
- **E2E Tests:** Critical user journeys (login, checkout, core workflows)

### 6.2 Unit Testing

```tsx
/**
 * ✅ Unit test: Utility function
 */
// utils/formatDate.test.ts
import { describe, it, expect } from 'vitest';
import { formatDate, formatRelativeDate } from './formatDate';

describe('formatDate', () => {
  it('should format ISO date to readable format', () => {
    expect(formatDate('2026-04-09T10:30:00Z')).toBe('Apr 9, 2026');
  });

  it('should return empty string for null input', () => {
    expect(formatDate(null)).toBe('');
  });

  it('should handle invalid date strings gracefully', () => {
    expect(formatDate('not-a-date')).toBe('Invalid date');
  });
});

describe('formatRelativeDate', () => {
  it('should return "just now" for dates less than a minute ago', () => {
    const now = new Date().toISOString();
    expect(formatRelativeDate(now)).toBe('just now');
  });
});
```

```tsx
/**
 * ✅ Unit test: Custom hook
 */
// hooks/useDebouncedValue.test.ts
import { renderHook, act } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { useDebouncedValue } from './useDebouncedValue';

describe('useDebouncedValue', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should return initial value immediately', () => {
    const { result } = renderHook(() => useDebouncedValue('hello', 300));
    expect(result.current).toBe('hello');
  });

  it('should debounce value updates', () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebouncedValue(value, delay),
      { initialProps: { value: 'hello', delay: 300 } }
    );

    rerender({ value: 'world', delay: 300 });
    expect(result.current).toBe('hello'); // Not updated yet

    act(() => { vi.advanceTimersByTime(300); });
    expect(result.current).toBe('world'); // Now updated
  });
});
```

```tsx
/**
 * ✅ Unit test: Zod validation schema
 */
// schemas/createUserSchema.test.ts
import { describe, it, expect } from 'vitest';
import { createUserSchema } from './createUserSchema';

describe('createUserSchema', () => {
  it('should validate a correct user input', () => {
    const result = createUserSchema.safeParse({
      email: 'john@example.com',
      firstName: 'John',
      lastName: 'Doe',
    });
    expect(result.success).toBe(true);
  });

  it('should reject invalid email', () => {
    const result = createUserSchema.safeParse({
      email: 'not-an-email',
      firstName: 'John',
      lastName: 'Doe',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].path).toEqual(['email']);
    }
  });

  it('should reject first name shorter than 2 characters', () => {
    const result = createUserSchema.safeParse({
      email: 'john@example.com',
      firstName: 'J',
      lastName: 'Doe',
    });
    expect(result.success).toBe(false);
  });

  it('should reject first name with invalid characters', () => {
    const result = createUserSchema.safeParse({
      email: 'john@example.com',
      firstName: 'John<script>',
      lastName: 'Doe',
    });
    expect(result.success).toBe(false);
  });
});
```

```tsx
/**
 * ✅ Unit test: Reducer
 */
// store/slices/cartSlice.test.ts
import { describe, it, expect } from 'vitest';
import { cartReducer, addItem, removeItem, clearCart, CartState } from './cartSlice';

describe('cartReducer', () => {
  const initialState: CartState = { items: [], total: 0 };

  it('should add an item to the cart', () => {
    const item = { id: '1', name: 'Widget', price: 10, quantity: 1 };
    const state = cartReducer(initialState, addItem(item));
    expect(state.items).toHaveLength(1);
    expect(state.items[0]).toEqual(item);
    expect(state.total).toBe(10);
  });

  it('should increment quantity for existing item', () => {
    const item = { id: '1', name: 'Widget', price: 10, quantity: 1 };
    let state = cartReducer(initialState, addItem(item));
    state = cartReducer(state, addItem(item));
    expect(state.items).toHaveLength(1);
    expect(state.items[0].quantity).toBe(2);
    expect(state.total).toBe(20);
  });

  it('should remove an item from the cart', () => {
    const item = { id: '1', name: 'Widget', price: 10, quantity: 1 };
    let state = cartReducer(initialState, addItem(item));
    state = cartReducer(state, removeItem('1'));
    expect(state.items).toHaveLength(0);
    expect(state.total).toBe(0);
  });

  it('should clear the cart', () => {
    const item = { id: '1', name: 'Widget', price: 10, quantity: 1 };
    let state = cartReducer(initialState, addItem(item));
    state = cartReducer(state, clearCart());
    expect(state.items).toHaveLength(0);
    expect(state.total).toBe(0);
  });
});
```

### 6.3 Component Testing

```tsx
/**
 * ✅ Component test with React Testing Library
 * Test BEHAVIOR, not implementation details.
 */
// features/users/components/UserTable.test.tsx
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { UserTable } from './UserTable';

const mockUsers = [
  { id: '1', firstName: 'John', lastName: 'Doe', email: 'john@example.com', status: 'ACTIVE', createdAt: '2026-01-01' },
  { id: '2', firstName: 'Jane', lastName: 'Smith', email: 'jane@example.com', status: 'INACTIVE', createdAt: '2026-02-01' },
];

describe('UserTable', () => {
  it('should render all users', () => {
    render(<UserTable users={mockUsers} />);

    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('Jane Smith')).toBeInTheDocument();
  });

  it('should display user email addresses', () => {
    render(<UserTable users={mockUsers} />);

    expect(screen.getByText('john@example.com')).toBeInTheDocument();
    expect(screen.getByText('jane@example.com')).toBeInTheDocument();
  });

  it('should call onRowClick when row is clicked', async () => {
    const handleRowClick = vi.fn();
    const user = userEvent.setup();

    render(<UserTable users={mockUsers} onRowClick={handleRowClick} />);

    await user.click(screen.getByText('John Doe'));
    expect(handleRowClick).toHaveBeenCalledWith(mockUsers[0]);
  });

  it('should be accessible with proper table roles', () => {
    render(<UserTable users={mockUsers} />);

    expect(screen.getByRole('table', { name: /users/i })).toBeInTheDocument();
    expect(screen.getAllByRole('row')).toHaveLength(3); // header + 2 data rows
    expect(screen.getByRole('columnheader', { name: /name/i })).toBeInTheDocument();
  });

  it('should show empty state when no users', () => {
    render(<UserTable users={[]} />);

    expect(screen.getByText(/no users found/i)).toBeInTheDocument();
  });
});
```

```tsx
/**
 * ✅ Form component test
 */
// features/users/components/CreateUserForm.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { CreateUserForm } from './CreateUserForm';

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      {ui}
    </QueryClientProvider>
  );
}

describe('CreateUserForm', () => {
  it('should show validation errors for empty required fields', async () => {
    const user = userEvent.setup();
    renderWithProviders(<CreateUserForm onSuccess={vi.fn()} />);

    await user.click(screen.getByRole('button', { name: /create/i }));

    await waitFor(() => {
      expect(screen.getByText(/email is required/i)).toBeInTheDocument();
      expect(screen.getByText(/first name/i)).toBeInTheDocument();
    });
  });

  it('should show validation error for invalid email', async () => {
    const user = userEvent.setup();
    renderWithProviders(<CreateUserForm onSuccess={vi.fn()} />);

    await user.type(screen.getByLabelText(/email/i), 'not-an-email');
    await user.click(screen.getByRole('button', { name: /create/i }));

    await waitFor(() => {
      expect(screen.getByText(/email must be valid/i)).toBeInTheDocument();
    });
  });

  it('should submit form with valid data', async () => {
    const handleSuccess = vi.fn();
    const user = userEvent.setup();
    renderWithProviders(<CreateUserForm onSuccess={handleSuccess} />);

    await user.type(screen.getByLabelText(/email/i), 'john@example.com');
    await user.type(screen.getByLabelText(/first name/i), 'John');
    await user.type(screen.getByLabelText(/last name/i), 'Doe');
    await user.click(screen.getByRole('button', { name: /create/i }));

    await waitFor(() => {
      expect(handleSuccess).toHaveBeenCalled();
    });
  });

  it('should disable submit button while submitting', async () => {
    const user = userEvent.setup();
    renderWithProviders(<CreateUserForm onSuccess={vi.fn()} />);

    await user.type(screen.getByLabelText(/email/i), 'john@example.com');
    await user.type(screen.getByLabelText(/first name/i), 'John');
    await user.type(screen.getByLabelText(/last name/i), 'Doe');
    await user.click(screen.getByRole('button', { name: /create/i }));

    expect(screen.getByRole('button', { name: /create/i })).toBeDisabled();
  });
});
```

### 6.4 Integration Testing with MSW (Mock Service Worker)

```tsx
/**
 * ✅ MSW handlers — mock API at the network level
 */
// mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/v1/users', () => {
    return HttpResponse.json({
      content: [
        { id: '1', firstName: 'John', lastName: 'Doe', email: 'john@example.com', status: 'ACTIVE' },
        { id: '2', firstName: 'Jane', lastName: 'Smith', email: 'jane@example.com', status: 'ACTIVE' },
      ],
      totalElements: 2,
      totalPages: 1,
      page: 0,
      size: 20,
    });
  }),

  http.post('/api/v1/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: '3', ...body, status: 'ACTIVE', createdAt: new Date().toISOString() },
      { status: 201 }
    );
  }),

  http.delete('/api/v1/users/:id', () => {
    return new HttpResponse(null, { status: 204 });
  }),
];

// mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

```tsx
/**
 * ✅ Integration test: Full feature page with mocked API
 */
// features/users/pages/UserListPage.integration.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { server } from '@/mocks/server';
import { http, HttpResponse } from 'msw';
import { AppProviders } from '@/providers/AppProviders';
import { UserListPage } from './UserListPage';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function renderPage() {
  return render(
    <AppProviders>
      <UserListPage />
    </AppProviders>
  );
}

describe('UserListPage Integration', () => {
  it('should load and display users from API', async () => {
    renderPage();

    // Initially shows loading state
    expect(screen.getByText(/loading/i)).toBeInTheDocument();

    // After API responds, shows users
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
      expect(screen.getByText('Jane Smith')).toBeInTheDocument();
    });
  });

  it('should display error state when API fails', async () => {
    server.use(
      http.get('/api/v1/users', () => {
        return HttpResponse.json(
          { message: 'Internal Server Error' },
          { status: 500 }
        );
      })
    );

    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/something went wrong/i)).toBeInTheDocument();
    });
  });

  it('should create a new user and refresh the list', async () => {
    const user = userEvent.setup();
    renderPage();

    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument();
    });

    await user.type(screen.getByLabelText(/email/i), 'new@example.com');
    await user.type(screen.getByLabelText(/first name/i), 'New');
    await user.type(screen.getByLabelText(/last name/i), 'User');
    await user.click(screen.getByRole('button', { name: /create/i }));

    await waitFor(() => {
      expect(screen.getByText(/user created/i)).toBeInTheDocument();
    });
  });
});
```

### 6.5 End-to-End Testing

```tsx
/**
 * ✅ E2E test with Playwright (critical user journeys)
 */
// e2e/users.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Management', () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto('/login');
    await page.getByLabel('Email').fill('admin@example.com');
    await page.getByLabel('Password').fill('SecurePass123!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await page.waitForURL('/users');
  });

  test('should display user list', async ({ page }) => {
    await expect(page.getByRole('table', { name: /users/i })).toBeVisible();
    await expect(page.getByRole('row')).toHaveCount({ minimum: 2 });
  });

  test('should create a new user', async ({ page }) => {
    await page.getByRole('button', { name: /create user/i }).click();

    await page.getByLabel('Email').fill('newuser@example.com');
    await page.getByLabel('First Name').fill('New');
    await page.getByLabel('Last Name').fill('User');
    await page.getByRole('button', { name: /submit/i }).click();

    await expect(page.getByText(/user created successfully/i)).toBeVisible();
    await expect(page.getByText('New User')).toBeVisible();
  });

  test('should show validation errors for invalid input', async ({ page }) => {
    await page.getByRole('button', { name: /create user/i }).click();
    await page.getByRole('button', { name: /submit/i }).click();

    await expect(page.getByText(/email is required/i)).toBeVisible();
  });
});
```

### 6.6 Accessibility Testing (NON-NEGOTIABLE)

```tsx
/**
 * ✅ Accessibility testing with jest-axe
 */
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

describe('Accessibility', () => {
  it('UserTable should have no accessibility violations', async () => {
    const { container } = render(<UserTable users={mockUsers} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('CreateUserForm should have no accessibility violations', async () => {
    const { container } = renderWithProviders(<CreateUserForm onSuccess={vi.fn()} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});

/**
 * ✅ Accessibility requirements checklist:
 * - All images have alt text
 * - All form inputs have associated labels
 * - All interactive elements are keyboard accessible
 * - Color is not the only means of conveying information
 * - Focus management for modals and dynamic content
 * - ARIA attributes used correctly
 * - Sufficient color contrast (WCAG AA: 4.5:1)
 */
```

### 6.7 Test Configuration

```tsx
/**
 * vitest.config.ts
 */
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.test.{ts,tsx}',
        'src/**/*.spec.{ts,tsx}',
        'src/test/**',
        'src/mocks/**',
        'src/types/**',
        'src/**/*.d.ts',
      ],
      thresholds: {
        statements: 80,
        branches: 75,
        functions: 80,
        lines: 80,
      },
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

/**
 * src/test/setup.ts
 */
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

afterEach(() => {
  cleanup();
});
```

---

## 7. Code Quality & Maintenance

### 7.1 ESLint Configuration

```jsonc
// .eslintrc.cjs
module.exports = {
  root: true,
  env: { browser: true, es2022: true },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: ['./tsconfig.json'],
    ecmaFeatures: { jsx: true },
  },
  plugins: [
    '@typescript-eslint',
    'react',
    'react-hooks',
    'jsx-a11y',
    'import',
    'testing-library',
  ],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'plugin:react/recommended',
    'plugin:react/jsx-runtime',
    'plugin:react-hooks/recommended',
    'plugin:jsx-a11y/recommended',
    'plugin:import/recommended',
    'plugin:import/typescript',
    'plugin:testing-library/react',
    'prettier',
  ],
  rules: {
    // TypeScript strictness
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/no-non-null-assertion': 'warn',

    // React best practices
    'react/prop-types': 'off', // TypeScript handles this
    'react/display-name': 'warn',
    'react/no-array-index-key': 'warn',
    'react/jsx-no-target-blank': 'error',
    'react/jsx-no-script-url': 'error',

    // Hooks rules (NON-NEGOTIABLE)
    'react-hooks/rules-of-hooks': 'error',
    'react-hooks/exhaustive-deps': 'warn',

    // Accessibility (NON-NEGOTIABLE)
    'jsx-a11y/anchor-is-valid': 'error',
    'jsx-a11y/click-events-have-key-events': 'error',
    'jsx-a11y/no-static-element-interactions': 'error',
    'jsx-a11y/img-redundant-alt': 'error',

    // Import order
    'import/order': ['error', {
      groups: ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
      'newlines-between': 'always',
      alphabetize: { order: 'asc', caseInsensitive: true },
    }],
    'import/no-cycle': 'error',
    'import/no-duplicates': 'error',

    // General quality
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'no-debugger': 'error',
    'prefer-const': 'error',
    'no-var': 'error',
    eqeqeq: ['error', 'always'],
  },
  settings: {
    react: { version: 'detect' },
    'import/resolver': {
      typescript: { project: './tsconfig.json' },
    },
  },
};
```

### 7.2 Prettier Configuration

```jsonc
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "useTabs": false,
  "trailingComma": "es5",
  "printWidth": 100,
  "bracketSpacing": true,
  "jsxSingleQuote": false,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

### 7.3 TypeScript Configuration

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,                           // NON-NEGOTIABLE
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

### 7.4 Git Hooks & Commit Standards

```jsonc
// package.json (partial)
{
  "scripts": {
    "lint": "eslint src --ext .ts,.tsx --max-warnings 0",
    "lint:fix": "eslint src --ext .ts,.tsx --fix",
    "format": "prettier --write 'src/**/*.{ts,tsx,css,json}'",
    "format:check": "prettier --check 'src/**/*.{ts,tsx,css,json}'",
    "type-check": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "validate": "npm run type-check && npm run lint && npm run test"
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix --max-warnings 0",
      "prettier --write"
    ],
    "*.{css,json,md}": [
      "prettier --write"
    ]
  }
}
```

```yaml
# .husky/pre-commit
npx lint-staged

# .husky/commit-msg
npx commitlint --edit $1
```

#### Conventional Commits (MANDATORY)

```
feat(users): add user search functionality
fix(auth): resolve token refresh race condition
docs(readme): update setup instructions
test(orders): add integration tests for order creation
refactor(api): extract HTTP client configuration
chore(deps): update react-query to v5
perf(users): memoize filtered user list
style(lint): fix import ordering
ci(pipeline): add accessibility check step
```

### 7.5 Dependency Management

| Category | Approved Libraries | Notes |
|----------|-------------------|-------|
| UI Framework | React 18+ | Functional components only |
| Build Tool | Vite | Fast HMR, ESBuild |
| Type System | TypeScript 5+ | `strict: true` required |
| State (Server) | TanStack Query v5 | Server state caching |
| State (Client) | Zustand or Redux Toolkit | Global client state |
| Routing | React Router v6+ | Lazy loading mandatory |
| Forms | React Hook Form + Zod | Schema-based validation |
| HTTP Client | Axios | Interceptors, cancellation |
| Testing | Vitest + React Testing Library | Component + unit tests |
| E2E Testing | Playwright | Critical user flows |
| API Mocking | MSW (Mock Service Worker) | Network-level mocks |
| Styling | CSS Modules or Tailwind CSS | Scoped styles |
| Linting | ESLint + Prettier | Enforced via pre-commit |
| Error Tracking | Sentry | Production monitoring |

### 7.6 Code Review Checklist

Before submitting a pull request, verify:

- [ ] **TypeScript:** No `any` types; strict mode passes (`tsc --noEmit`)
- [ ] **Components:** Functional only; props have typed interfaces
- [ ] **State:** Server state uses TanStack Query; no `useEffect` for derived state
- [ ] **Security:** No `dangerouslySetInnerHTML` with unsanitized input; tokens in memory only
- [ ] **Accessibility:** All forms labeled; interactive elements keyboard-accessible; `axe` passes
- [ ] **Performance:** Route-level code splitting; `useMemo`/`useCallback` for expensive ops
- [ ] **Testing:** Unit tests for hooks/utils; component tests for behavior; coverage thresholds met
- [ ] **Imports:** Tree-shakable; no circular dependencies; import order enforced
- [ ] **Naming:** PascalCase components; `use` prefix hooks; consistent event handler naming
- [ ] **Error Handling:** Error boundaries wrap routes; API errors display user-friendly messages
- [ ] **Logging:** No `console.log` in production; structured logger used
- [ ] **Commits:** Conventional commit format; atomic PR scope

### 7.7 CI/CD Quality Gates

```yaml
# Pipeline quality gates (must pass before merge)
quality-gates:
  - name: Type Check
    command: npm run type-check
    blocking: true

  - name: Lint
    command: npm run lint
    blocking: true

  - name: Unit & Component Tests
    command: npm run test:coverage
    blocking: true
    thresholds:
      statements: 80%
      branches: 75%
      functions: 80%

  - name: Build
    command: npm run build
    blocking: true

  - name: Bundle Size Check
    command: npx bundlesize
    blocking: true
    limits:
      - path: dist/assets/index-*.js
        maxSize: 250kB gzip

  - name: Accessibility Audit
    command: npx pa11y-ci
    blocking: true

  - name: E2E Tests
    command: npx playwright test
    blocking: true
    runOn: staging
```
