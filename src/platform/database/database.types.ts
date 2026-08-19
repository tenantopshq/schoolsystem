export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      academic_terms: {
        Row: {
          academic_year_id: string
          created_at: string
          created_by: string | null
          end_date: string
          grading_end_at: string | null
          grading_start_at: string | null
          id: string
          name: string
          organization_id: string
          sequence: number
          start_date: string
          status: Database["public"]["Enums"]["academic_period_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          academic_year_id: string
          created_at?: string
          created_by?: string | null
          end_date: string
          grading_end_at?: string | null
          grading_start_at?: string | null
          id?: string
          name: string
          organization_id: string
          sequence: number
          start_date: string
          status?: Database["public"]["Enums"]["academic_period_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          academic_year_id?: string
          created_at?: string
          created_by?: string | null
          end_date?: string
          grading_end_at?: string | null
          grading_start_at?: string | null
          id?: string
          name?: string
          organization_id?: string
          sequence?: number
          start_date?: string
          status?: Database["public"]["Enums"]["academic_period_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "academic_terms_organization_id_academic_year_id_fkey"
            columns: ["organization_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      academic_years: {
        Row: {
          created_at: string
          created_by: string | null
          end_date: string
          id: string
          is_current: boolean
          name: string
          organization_id: string
          school_id: string
          start_date: string
          status: Database["public"]["Enums"]["academic_period_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          end_date: string
          id?: string
          is_current?: boolean
          name: string
          organization_id: string
          school_id: string
          start_date: string
          status?: Database["public"]["Enums"]["academic_period_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          end_date?: string
          id?: string
          is_current?: boolean
          name?: string
          organization_id?: string
          school_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["academic_period_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "academic_years_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor_user_id: string | null
          after_data: Json | null
          before_data: Json | null
          command_id: string | null
          entity_id: string | null
          entity_type: string
          id: string
          ip_address: unknown
          occurred_at: string
          organization_id: string
          user_agent: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          command_id?: string | null
          entity_id?: string | null
          entity_type: string
          id?: string
          ip_address?: unknown
          occurred_at?: string
          organization_id: string
          user_agent?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          command_id?: string | null
          entity_id?: string | null
          entity_type?: string
          id?: string
          ip_address?: unknown
          occurred_at?: string
          organization_id?: string
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      buildings: {
        Row: {
          campus_id: string
          closed_on: string | null
          code: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          opened_on: string | null
          organization_id: string
          school_id: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          campus_id: string
          closed_on?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          opened_on?: string | null
          organization_id: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          campus_id?: string
          closed_on?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          opened_on?: string | null
          organization_id?: string
          school_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "buildings_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "buildings_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "buildings_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      campuses: {
        Row: {
          address_line_1: string | null
          address_line_2: string | null
          city: string | null
          code: string
          country_code: string | null
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          name: string
          organization_id: string
          phone: string | null
          postal_code: string | null
          school_id: string
          state_region: string | null
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address_line_1?: string | null
          address_line_2?: string | null
          city?: string | null
          code: string
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name: string
          organization_id: string
          phone?: string | null
          postal_code?: string | null
          school_id: string
          state_region?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address_line_1?: string | null
          address_line_2?: string | null
          city?: string | null
          code?: string
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          name?: string
          organization_id?: string
          phone?: string | null
          postal_code?: string | null
          school_id?: string
          state_region?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "campuses_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      event_outbox: {
        Row: {
          aggregate_id: string
          aggregate_type: string
          command_id: string | null
          event_type: string
          id: string
          last_error: string | null
          occurred_at: string
          organization_id: string
          payload: Json
          processed_at: string | null
          retry_count: number
          status: Database["public"]["Enums"]["outbox_status"]
        }
        Insert: {
          aggregate_id: string
          aggregate_type: string
          command_id?: string | null
          event_type: string
          id?: string
          last_error?: string | null
          occurred_at?: string
          organization_id: string
          payload?: Json
          processed_at?: string | null
          retry_count?: number
          status?: Database["public"]["Enums"]["outbox_status"]
        }
        Update: {
          aggregate_id?: string
          aggregate_type?: string
          command_id?: string | null
          event_type?: string
          id?: string
          last_error?: string | null
          occurred_at?: string
          organization_id?: string
          payload?: Json
          processed_at?: string | null
          retry_count?: number
          status?: Database["public"]["Enums"]["outbox_status"]
        }
        Relationships: [
          {
            foreignKeyName: "event_outbox_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      grade_levels: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          maximum_age: number | null
          minimum_age: number | null
          name: string
          organization_id: string
          school_id: string
          sequence: number
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          maximum_age?: number | null
          minimum_age?: number | null
          name: string
          organization_id: string
          school_id: string
          sequence: number
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          maximum_age?: number | null
          minimum_age?: number | null
          name?: string
          organization_id?: string
          school_id?: string
          sequence?: number
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "grade_levels_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      guardians: {
        Row: {
          alternate_phone: string | null
          created_at: string
          created_by: string | null
          email: string | null
          first_name: string
          id: string
          last_name: string
          middle_name: string | null
          occupation: string | null
          organization_id: string
          phone: string | null
          preferred_language: string | null
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
          user_id: string | null
        }
        Insert: {
          alternate_phone?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          first_name: string
          id?: string
          last_name: string
          middle_name?: string | null
          occupation?: string | null
          organization_id: string
          phone?: string | null
          preferred_language?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Update: {
          alternate_phone?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          first_name?: string
          id?: string
          last_name?: string
          middle_name?: string | null
          occupation?: string | null
          organization_id?: string
          phone?: string | null
          preferred_language?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guardians_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_memberships: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          joined_at: string | null
          left_at: string | null
          organization_id: string
          status: Database["public"]["Enums"]["membership_status"]
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          joined_at?: string | null
          left_at?: string | null
          organization_id: string
          status?: Database["public"]["Enums"]["membership_status"]
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          joined_at?: string | null
          left_at?: string | null
          organization_id?: string
          status?: Database["public"]["Enums"]["membership_status"]
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string | null
          default_currency: string
          default_locale: string
          default_timezone: string
          id: string
          legal_name: string | null
          name: string
          parent_organization_id: string | null
          slug: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          default_currency?: string
          default_locale?: string
          default_timezone?: string
          id?: string
          legal_name?: string | null
          name: string
          parent_organization_id?: string | null
          slug: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          default_currency?: string
          default_locale?: string
          default_timezone?: string
          id?: string
          legal_name?: string | null
          name?: string
          parent_organization_id?: string | null
          slug?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "organizations_parent_organization_id_fkey"
            columns: ["parent_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          code: string
          created_at: string
          description: string
          id: string
          module: string
        }
        Insert: {
          code: string
          created_at?: string
          description: string
          id?: string
          module: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string
          id?: string
          module?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_path: string | null
          created_at: string
          display_name: string | null
          first_name: string | null
          last_name: string | null
          middle_name: string | null
          phone: string | null
          preferred_locale: string
          status: Database["public"]["Enums"]["record_status"]
          timezone: string
          updated_at: string
          user_id: string
        }
        Insert: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string | null
          first_name?: string | null
          last_name?: string | null
          middle_name?: string | null
          phone?: string | null
          preferred_locale?: string
          status?: Database["public"]["Enums"]["record_status"]
          timezone?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string | null
          first_name?: string | null
          last_name?: string | null
          middle_name?: string | null
          phone?: string | null
          preferred_locale?: string
          status?: Database["public"]["Enums"]["record_status"]
          timezone?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      role_assignments: {
        Row: {
          campus_id: string | null
          created_at: string
          created_by: string | null
          ends_at: string | null
          id: string
          organization_id: string
          organization_membership_id: string
          role_id: string
          school_id: string | null
          starts_at: string
          status: Database["public"]["Enums"]["role_assignment_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          organization_id: string
          organization_membership_id: string
          role_id: string
          school_id?: string | null
          starts_at?: string
          status?: Database["public"]["Enums"]["role_assignment_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          organization_id?: string
          organization_membership_id?: string
          role_id?: string
          school_id?: string | null
          starts_at?: string
          status?: Database["public"]["Enums"]["role_assignment_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "role_assignments_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_organization_membership_i_fkey"
            columns: ["organization_id", "organization_membership_id"]
            isOneToOne: false
            referencedRelation: "organization_memberships"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_role_id_fkey"
            columns: ["organization_id", "role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_assignments_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          created_by: string | null
          organization_id: string
          permission_id: string
          role_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          organization_id: string
          permission_id: string
          role_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          organization_id?: string
          permission_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_organization_id_role_id_fkey"
            columns: ["organization_id", "role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          is_system_role: boolean
          name: string
          organization_id: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system_role?: boolean
          name: string
          organization_id: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system_role?: boolean
          name?: string
          organization_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "roles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          building_id: string
          campus_id: string
          capacity: number
          code: string
          created_at: string
          created_by: string | null
          floor_label: string | null
          id: string
          name: string
          organization_id: string
          room_type: string
          school_id: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          building_id: string
          campus_id: string
          capacity: number
          code: string
          created_at?: string
          created_by?: string | null
          floor_label?: string | null
          id?: string
          name: string
          organization_id: string
          room_type: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          building_id?: string
          campus_id?: string
          capacity?: number
          code?: string
          created_at?: string
          created_by?: string | null
          floor_label?: string | null
          id?: string
          name?: string
          organization_id?: string
          room_type?: string
          school_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rooms_organization_id_school_id_campus_id_building_id_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "building_id",
            ]
            isOneToOne: false
            referencedRelation: "buildings"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "id",
            ]
          },
        ]
      }
      schools: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          default_locale: string | null
          email: string | null
          id: string
          legal_name: string | null
          name: string
          organization_id: string
          phone: string | null
          status: Database["public"]["Enums"]["record_status"]
          timezone: string | null
          updated_at: string
          updated_by: string | null
          website: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          default_locale?: string | null
          email?: string | null
          id?: string
          legal_name?: string | null
          name: string
          organization_id: string
          phone?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          timezone?: string | null
          updated_at?: string
          updated_by?: string | null
          website?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          default_locale?: string | null
          email?: string | null
          id?: string
          legal_name?: string | null
          name?: string
          organization_id?: string
          phone?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          timezone?: string | null
          updated_at?: string
          updated_by?: string | null
          website?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "schools_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      sections: {
        Row: {
          academic_term_id: string | null
          academic_year_id: string
          campus_id: string
          capacity: number
          code: string
          created_at: string
          created_by: string | null
          end_date: string
          grade_level_id: string
          homeroom_room_id: string | null
          id: string
          name: string
          organization_id: string
          school_id: string
          start_date: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          academic_term_id?: string | null
          academic_year_id: string
          campus_id: string
          capacity: number
          code: string
          created_at?: string
          created_by?: string | null
          end_date: string
          grade_level_id: string
          homeroom_room_id?: string | null
          id?: string
          name: string
          organization_id: string
          school_id: string
          start_date: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          academic_term_id?: string | null
          academic_year_id?: string
          campus_id?: string
          capacity?: number
          code?: string
          created_at?: string
          created_by?: string | null
          end_date?: string
          grade_level_id?: string
          homeroom_room_id?: string | null
          id?: string
          name?: string
          organization_id?: string
          school_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sections_organization_id_academic_year_id_academic_term_id_fkey"
            columns: ["organization_id", "academic_year_id", "academic_term_id"]
            isOneToOne: false
            referencedRelation: "academic_terms"
            referencedColumns: ["organization_id", "academic_year_id", "id"]
          },
          {
            foreignKeyName: "sections_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "sections_organization_id_school_id_academic_year_id_fkey"
            columns: ["organization_id", "school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "sections_organization_id_school_id_campus_id_homeroom_room_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "homeroom_room_id",
            ]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "id",
            ]
          },
          {
            foreignKeyName: "sections_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "sections_organization_id_school_id_grade_level_id_fkey"
            columns: ["organization_id", "school_id", "grade_level_id"]
            isOneToOne: false
            referencedRelation: "grade_levels"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "sections_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      staff_profiles: {
        Row: {
          campus_id: string | null
          created_at: string
          created_by: string | null
          department: string | null
          employment_type: string
          hire_date: string | null
          id: string
          job_title: string | null
          organization_id: string
          organization_membership_id: string
          school_id: string | null
          staff_number: string
          status: Database["public"]["Enums"]["record_status"]
          termination_date: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          department?: string | null
          employment_type: string
          hire_date?: string | null
          id?: string
          job_title?: string | null
          organization_id: string
          organization_membership_id: string
          school_id?: string | null
          staff_number: string
          status?: Database["public"]["Enums"]["record_status"]
          termination_date?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          department?: string | null
          employment_type?: string
          hire_date?: string | null
          id?: string
          job_title?: string | null
          organization_id?: string
          organization_membership_id?: string
          school_id?: string | null
          staff_number?: string
          status?: Database["public"]["Enums"]["record_status"]
          termination_date?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "staff_profiles_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "staff_profiles_organization_id_organization_membership_id_fkey"
            columns: ["organization_id", "organization_membership_id"]
            isOneToOne: true
            referencedRelation: "organization_memberships"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "staff_profiles_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "staff_profiles_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      student_addresses: {
        Row: {
          address_type: string
          city: string
          country_code: string
          created_at: string
          created_by: string | null
          id: string
          is_primary: boolean
          line_1: string
          line_2: string | null
          organization_id: string
          postal_code: string | null
          state_region: string | null
          student_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address_type: string
          city: string
          country_code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_primary?: boolean
          line_1: string
          line_2?: string | null
          organization_id: string
          postal_code?: string | null
          state_region?: string | null
          student_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address_type?: string
          city?: string
          country_code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_primary?: boolean
          line_1?: string
          line_2?: string | null
          organization_id?: string
          postal_code?: string | null
          state_region?: string | null
          student_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "student_addresses_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_addresses_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      student_documents: {
        Row: {
          created_at: string
          created_by: string | null
          document_type: string
          expires_at: string | null
          file_size: number | null
          id: string
          issued_at: string | null
          mime_type: string | null
          organization_id: string
          status: Database["public"]["Enums"]["record_status"]
          storage_path: string
          student_id: string
          title: string
          updated_at: string
          updated_by: string | null
          visibility: Database["public"]["Enums"]["student_document_visibility"]
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          document_type: string
          expires_at?: string | null
          file_size?: number | null
          id?: string
          issued_at?: string | null
          mime_type?: string | null
          organization_id: string
          status?: Database["public"]["Enums"]["record_status"]
          storage_path: string
          student_id: string
          title: string
          updated_at?: string
          updated_by?: string | null
          visibility?: Database["public"]["Enums"]["student_document_visibility"]
        }
        Update: {
          created_at?: string
          created_by?: string | null
          document_type?: string
          expires_at?: string | null
          file_size?: number | null
          id?: string
          issued_at?: string | null
          mime_type?: string | null
          organization_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          storage_path?: string
          student_id?: string
          title?: string
          updated_at?: string
          updated_by?: string | null
          visibility?: Database["public"]["Enums"]["student_document_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "student_documents_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_documents_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      student_emergency_contacts: {
        Row: {
          alternate_phone: string | null
          created_at: string
          created_by: string | null
          guardian_id: string | null
          id: string
          name: string
          organization_id: string
          phone: string
          priority: number
          relationship: string
          student_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          alternate_phone?: string | null
          created_at?: string
          created_by?: string | null
          guardian_id?: string | null
          id?: string
          name: string
          organization_id: string
          phone: string
          priority: number
          relationship: string
          student_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          alternate_phone?: string | null
          created_at?: string
          created_by?: string | null
          guardian_id?: string | null
          id?: string
          name?: string
          organization_id?: string
          phone?: string
          priority?: number
          relationship?: string
          student_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "student_emergency_contacts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_emergency_contacts_organization_id_guardian_id_fkey"
            columns: ["organization_id", "guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "student_emergency_contacts_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      student_guardians: {
        Row: {
          created_at: string
          created_by: string | null
          financial_responsibility: boolean
          guardian_id: string
          has_portal_access: boolean
          id: string
          is_primary: boolean
          organization_id: string
          pickup_authorized: boolean
          receives_academic_updates: boolean
          receives_attendance_alerts: boolean
          relationship_type: string
          status: Database["public"]["Enums"]["record_status"]
          student_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          financial_responsibility?: boolean
          guardian_id: string
          has_portal_access?: boolean
          id?: string
          is_primary?: boolean
          organization_id: string
          pickup_authorized?: boolean
          receives_academic_updates?: boolean
          receives_attendance_alerts?: boolean
          relationship_type: string
          status?: Database["public"]["Enums"]["record_status"]
          student_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          financial_responsibility?: boolean
          guardian_id?: string
          has_portal_access?: boolean
          id?: string
          is_primary?: boolean
          organization_id?: string
          pickup_authorized?: boolean
          receives_academic_updates?: boolean
          receives_attendance_alerts?: boolean
          relationship_type?: string
          status?: Database["public"]["Enums"]["record_status"]
          student_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "student_guardians_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_guardians_organization_id_guardian_id_fkey"
            columns: ["organization_id", "guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "student_guardians_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      student_identifiers: {
        Row: {
          country_code: string | null
          created_at: string
          created_by: string | null
          expires_at: string | null
          id: string
          identifier_type: string
          identifier_value: string
          issued_at: string | null
          organization_id: string
          student_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          expires_at?: string | null
          id?: string
          identifier_type: string
          identifier_value: string
          issued_at?: string | null
          organization_id: string
          student_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          expires_at?: string | null
          id?: string
          identifier_type?: string
          identifier_value?: string
          issued_at?: string | null
          organization_id?: string
          student_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "student_identifiers_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_identifiers_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      students: {
        Row: {
          admission_date: string | null
          campus_id: string | null
          created_at: string
          created_by: string | null
          date_of_birth: string
          exit_date: string | null
          first_name: string
          gender: string | null
          id: string
          last_name: string
          middle_name: string | null
          nationality_code: string | null
          organization_id: string
          photo_path: string | null
          preferred_name: string | null
          primary_language: string | null
          school_id: string
          status: Database["public"]["Enums"]["record_status"]
          student_number: string
          updated_at: string
          updated_by: string | null
          user_id: string | null
        }
        Insert: {
          admission_date?: string | null
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          date_of_birth: string
          exit_date?: string | null
          first_name: string
          gender?: string | null
          id?: string
          last_name: string
          middle_name?: string | null
          nationality_code?: string | null
          organization_id: string
          photo_path?: string | null
          preferred_name?: string | null
          primary_language?: string | null
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          student_number: string
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Update: {
          admission_date?: string | null
          campus_id?: string | null
          created_at?: string
          created_by?: string | null
          date_of_birth?: string
          exit_date?: string | null
          first_name?: string
          gender?: string | null
          id?: string
          last_name?: string
          middle_name?: string | null
          nationality_code?: string | null
          organization_id?: string
          photo_path?: string | null
          preferred_name?: string | null
          primary_language?: string | null
          school_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          student_number?: string
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "students_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "students_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "students_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      subjects: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          name: string
          organization_id: string
          school_id: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name: string
          organization_id: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name?: string
          organization_id?: string
          school_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subjects_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      archive_building: { Args: { id: string }; Returns: string }
      archive_grade_level: { Args: { id: string }; Returns: string }
      archive_room: { Args: { id: string }; Returns: string }
      archive_section: { Args: { id: string }; Returns: string }
      archive_staff_profile: { Args: { id: string }; Returns: string }
      archive_student: {
        Args: { archive_reason: string; target_student_id: string }
        Returns: string
      }
      archive_subject: { Args: { id: string }; Returns: string }
      create_academic_term: {
        Args: {
          academic_year_id: string
          end_date: string
          name: string
          sequence: number
          start_date: string
          status?: Database["public"]["Enums"]["academic_period_status"]
        }
        Returns: string
      }
      create_academic_year: {
        Args: {
          end_date: string
          name: string
          school_id: string
          start_date: string
          status?: Database["public"]["Enums"]["academic_period_status"]
        }
        Returns: string
      }
      create_building: {
        Args: {
          campus_id: string
          code: string
          name: string
          opened_on?: string
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      create_grade_level: {
        Args: {
          code: string
          maximum_age?: number
          minimum_age?: number
          name: string
          school_id: string
          sequence: number
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      create_room: {
        Args: {
          building_id: string
          capacity: number
          code: string
          name: string
          room_type: string
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      create_section: {
        Args: {
          academic_term_id: string
          academic_year_id: string
          campus_id: string
          capacity: number
          code: string
          end_date: string
          grade_level_id: string
          homeroom_room_id: string
          name: string
          start_date: string
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      create_staff_profile: {
        Args: {
          campus_id: string
          department?: string
          employment_type: string
          hire_date?: string
          job_title?: string
          membership_id: string
          school_id: string
          staff_number: string
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      create_subject: {
        Args: {
          code: string
          description?: string
          name: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      transition_academic_term_status: {
        Args: {
          id: string
          status: Database["public"]["Enums"]["academic_period_status"]
        }
        Returns: string
      }
      transition_academic_year_status: {
        Args: {
          id: string
          status: Database["public"]["Enums"]["academic_period_status"]
        }
        Returns: string
      }
      update_academic_term: {
        Args: {
          end_date: string
          id: string
          name: string
          sequence: number
          start_date: string
        }
        Returns: string
      }
      update_academic_year: {
        Args: { end_date: string; id: string; name: string; start_date: string }
        Returns: string
      }
      update_building: {
        Args: {
          closed_on?: string
          code: string
          id: string
          name: string
          opened_on?: string
          set_closed_on?: boolean
          set_opened_on?: boolean
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_grade_level: {
        Args: {
          code: string
          id: string
          maximum_age?: number
          minimum_age?: number
          name: string
          sequence: number
          set_maximum_age?: boolean
          set_minimum_age?: boolean
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_room: {
        Args: {
          capacity: number
          code: string
          floor_label?: string
          id: string
          name: string
          room_type: string
          set_floor_label?: boolean
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_section: {
        Args: {
          academic_term_id: string
          capacity: number
          code: string
          end_date: string
          homeroom_room_id: string
          id: string
          name: string
          set_academic_term_id?: boolean
          set_homeroom_room_id?: boolean
          start_date: string
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_staff_profile: {
        Args: {
          campus_id?: string
          department?: string
          employment_type: string
          hire_date?: string
          id: string
          job_title?: string
          school_id?: string
          set_campus_id?: boolean
          set_department?: boolean
          set_hire_date?: boolean
          set_job_title?: boolean
          set_school_id?: boolean
          set_termination_date?: boolean
          staff_number: string
          status: Database["public"]["Enums"]["record_status"]
          termination_date?: string
        }
        Returns: string
      }
      update_subject: {
        Args: {
          code: string
          description: string
          id: string
          name: string
          set_description?: boolean
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
    }
    Enums: {
      academic_period_status: "draft" | "active" | "closed" | "archived"
      membership_status: "invited" | "active" | "suspended" | "left"
      outbox_status: "pending" | "processing" | "processed" | "failed"
      record_status: "active" | "inactive" | "archived"
      role_assignment_status: "active" | "inactive"
      student_document_visibility:
        | "admin_only"
        | "staff"
        | "guardian"
        | "student"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      academic_period_status: ["draft", "active", "closed", "archived"],
      membership_status: ["invited", "active", "suspended", "left"],
      outbox_status: ["pending", "processing", "processed", "failed"],
      record_status: ["active", "inactive", "archived"],
      role_assignment_status: ["active", "inactive"],
      student_document_visibility: [
        "admin_only",
        "staff",
        "guardian",
        "student",
      ],
    },
  },
} as const
