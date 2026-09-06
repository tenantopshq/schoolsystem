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
      assessment_results: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          assessment_id: string
          assessment_student_id: string
          campus_id: string
          created_at: string
          created_by: string
          id: string
          organization_id: string
          school_id: string
          score: number | null
          section_id: string
          student_id: string
          teacher_comment: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          assessment_id: string
          assessment_student_id: string
          campus_id: string
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          school_id: string
          score?: number | null
          section_id: string
          student_id: string
          teacher_comment?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          assessment_id?: string
          assessment_student_id?: string
          campus_id?: string
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          school_id?: string
          score?: number | null
          section_id?: string
          student_id?: string
          teacher_comment?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "assessment_results_organization_id_school_id_campus_id_ac_fkey1"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "assessment_id",
              "student_id",
              "assessment_student_id",
            ]
            isOneToOne: false
            referencedRelation: "assessment_students"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "assessment_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "assessment_results_organization_id_school_id_campus_id_aca_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "assessment_id",
            ]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "id",
            ]
          },
        ]
      }
      assessment_students: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          assessment_id: string
          campus_id: string
          created_at: string
          created_by: string
          id: string
          organization_id: string
          school_id: string
          section_id: string
          student_enrollment_id: string
          student_id: string
          student_section_placement_id: string
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          assessment_id: string
          campus_id: string
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          school_id: string
          section_id: string
          student_enrollment_id: string
          student_id: string
          student_section_placement_id: string
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          assessment_id?: string
          campus_id?: string
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          school_id?: string
          section_id?: string
          student_enrollment_id?: string
          student_id?: string
          student_section_placement_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "assessment_students_organization_id_school_id_academic_yea_fkey"
            columns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "student_enrollment_id",
            ]
            isOneToOne: false
            referencedRelation: "student_enrollments"
            referencedColumns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "assessment_students_organization_id_school_id_campus_id_a_fkey1"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "student_id",
              "student_enrollment_id",
              "student_section_placement_id",
            ]
            isOneToOne: false
            referencedRelation: "student_section_placements"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "student_id",
              "student_enrollment_id",
              "id",
            ]
          },
          {
            foreignKeyName: "assessment_students_organization_id_school_id_campus_id_ac_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "assessment_id",
            ]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "id",
            ]
          },
          {
            foreignKeyName: "assessment_students_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      assessments: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          assessment_date: string
          assessment_type: Database["public"]["Enums"]["assessment_type"]
          campus_id: string
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          correction_reason: string | null
          created_at: string
          created_by: string
          description: string | null
          due_date: string | null
          finalized_at: string | null
          finalized_by: string | null
          id: string
          lifecycle_status: Database["public"]["Enums"]["assessment_lifecycle_status"]
          maximum_score: number
          organization_id: string
          publication_state: Database["public"]["Enums"]["assessment_publication_state"]
          published_at: string | null
          published_by: string | null
          school_id: string
          section_id: string
          subject_id: string | null
          supersedes_assessment_id: string | null
          title: string
          updated_at: string
          updated_by: string
          weight: number | null
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          assessment_date: string
          assessment_type: Database["public"]["Enums"]["assessment_type"]
          campus_id: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          correction_reason?: string | null
          created_at?: string
          created_by: string
          description?: string | null
          due_date?: string | null
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          lifecycle_status?: Database["public"]["Enums"]["assessment_lifecycle_status"]
          maximum_score: number
          organization_id: string
          publication_state?: Database["public"]["Enums"]["assessment_publication_state"]
          published_at?: string | null
          published_by?: string | null
          school_id: string
          section_id: string
          subject_id?: string | null
          supersedes_assessment_id?: string | null
          title: string
          updated_at?: string
          updated_by: string
          weight?: number | null
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          assessment_date?: string
          assessment_type?: Database["public"]["Enums"]["assessment_type"]
          campus_id?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          description?: string | null
          due_date?: string | null
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          lifecycle_status?: Database["public"]["Enums"]["assessment_lifecycle_status"]
          maximum_score?: number
          organization_id?: string
          publication_state?: Database["public"]["Enums"]["assessment_publication_state"]
          published_at?: string | null
          published_by?: string | null
          school_id?: string
          section_id?: string
          subject_id?: string | null
          supersedes_assessment_id?: string | null
          title?: string
          updated_at?: string
          updated_by?: string
          weight?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "assessments_organization_id_academic_year_id_academic_term_fkey"
            columns: ["organization_id", "academic_year_id", "academic_term_id"]
            isOneToOne: false
            referencedRelation: "academic_terms"
            referencedColumns: ["organization_id", "academic_year_id", "id"]
          },
          {
            foreignKeyName: "assessments_organization_id_school_id_campus_id_academic_y_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
            ]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "id",
            ]
          },
          {
            foreignKeyName: "assessments_organization_id_school_id_subject_id_fkey"
            columns: ["organization_id", "school_id", "subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "assessments_organization_id_supersedes_assessment_id_fkey"
            columns: ["organization_id", "supersedes_assessment_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      attendance_absence_reasons: {
        Row: {
          campus_id: string | null
          code: string
          created_at: string
          created_by: string
          description: string | null
          id: string
          name: string
          organization_id: string
          school_id: string
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          updated_by: string
        }
        Insert: {
          campus_id?: string | null
          code: string
          created_at?: string
          created_by: string
          description?: string | null
          id?: string
          name: string
          organization_id: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by: string
        }
        Update: {
          campus_id?: string | null
          code?: string
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          name?: string
          organization_id?: string
          school_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_absence_reasons_organization_id_campus_id_fkey"
            columns: ["organization_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_absence_reasons_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_absence_reasons_school_id_campus_id_fkey"
            columns: ["school_id", "campus_id"]
            isOneToOne: false
            referencedRelation: "campuses"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      attendance_marks: {
        Row: {
          absence_reason_id: string | null
          academic_year_id: string
          arrival_time: string | null
          campus_id: string
          created_at: string
          created_by: string
          id: string
          mark: Database["public"]["Enums"]["attendance_mark_status"]
          note: string | null
          organization_id: string
          school_id: string
          section_id: string
          session_id: string
          session_student_id: string
          student_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          absence_reason_id?: string | null
          academic_year_id: string
          arrival_time?: string | null
          campus_id: string
          created_at?: string
          created_by: string
          id?: string
          mark: Database["public"]["Enums"]["attendance_mark_status"]
          note?: string | null
          organization_id: string
          school_id: string
          section_id: string
          session_id: string
          session_student_id: string
          student_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          absence_reason_id?: string | null
          academic_year_id?: string
          arrival_time?: string | null
          campus_id?: string
          created_at?: string
          created_by?: string
          id?: string
          mark?: Database["public"]["Enums"]["attendance_mark_status"]
          note?: string | null
          organization_id?: string
          school_id?: string
          section_id?: string
          session_id?: string
          session_student_id?: string
          student_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_marks_organization_id_school_id_absence_reason__fkey"
            columns: ["organization_id", "school_id", "absence_reason_id"]
            isOneToOne: false
            referencedRelation: "attendance_absence_reasons"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "attendance_marks_organization_id_school_id_campus_id_acad_fkey1"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "session_id",
              "student_id",
              "session_student_id",
            ]
            isOneToOne: false
            referencedRelation: "attendance_session_students"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "session_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "attendance_marks_organization_id_school_id_campus_id_acade_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "session_id",
            ]
            isOneToOne: false
            referencedRelation: "attendance_sessions"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "id",
            ]
          },
        ]
      }
      attendance_session_students: {
        Row: {
          academic_year_id: string
          campus_id: string
          created_at: string
          created_by: string
          id: string
          organization_id: string
          school_id: string
          section_id: string
          session_id: string
          student_enrollment_id: string
          student_id: string
          student_section_placement_id: string
        }
        Insert: {
          academic_year_id: string
          campus_id: string
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          school_id: string
          section_id: string
          session_id: string
          student_enrollment_id: string
          student_id: string
          student_section_placement_id: string
        }
        Update: {
          academic_year_id?: string
          campus_id?: string
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          school_id?: string
          section_id?: string
          session_id?: string
          student_enrollment_id?: string
          student_id?: string
          student_section_placement_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_session_students_organization_id_school_id_acad_fkey"
            columns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "student_enrollment_id",
            ]
            isOneToOne: false
            referencedRelation: "student_enrollments"
            referencedColumns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "attendance_session_students_organization_id_school_id_cam_fkey1"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "student_id",
              "student_enrollment_id",
              "student_section_placement_id",
            ]
            isOneToOne: false
            referencedRelation: "student_section_placements"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "student_id",
              "student_enrollment_id",
              "id",
            ]
          },
          {
            foreignKeyName: "attendance_session_students_organization_id_school_id_camp_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "session_id",
            ]
            isOneToOne: false
            referencedRelation: "attendance_sessions"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
              "id",
            ]
          },
          {
            foreignKeyName: "attendance_session_students_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      attendance_sessions: {
        Row: {
          academic_year_id: string
          campus_id: string
          correction_reason: string | null
          created_at: string
          created_by: string
          finalized_at: string | null
          finalized_by: string | null
          id: string
          organization_id: string
          school_id: string
          section_id: string
          session_date: string
          status: Database["public"]["Enums"]["attendance_session_status"]
          submitted_at: string | null
          submitted_by: string | null
          supersedes_session_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_year_id: string
          campus_id: string
          correction_reason?: string | null
          created_at?: string
          created_by: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          organization_id: string
          school_id: string
          section_id: string
          session_date: string
          status?: Database["public"]["Enums"]["attendance_session_status"]
          submitted_at?: string | null
          submitted_by?: string | null
          supersedes_session_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_year_id?: string
          campus_id?: string
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          organization_id?: string
          school_id?: string
          section_id?: string
          session_date?: string
          status?: Database["public"]["Enums"]["attendance_session_status"]
          submitted_at?: string | null
          submitted_by?: string | null
          supersedes_session_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_sessions_organization_id_school_id_campus_id_ac_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
            ]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "id",
            ]
          },
          {
            foreignKeyName: "attendance_sessions_organization_id_supersedes_session_id_fkey"
            columns: ["organization_id", "supersedes_session_id"]
            isOneToOne: false
            referencedRelation: "attendance_sessions"
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
      grade_scale_bands: {
        Row: {
          created_at: string
          created_by: string
          grade_scale_id: string
          id: string
          label: string
          lower_units: number
          organization_id: string
          percentage_range: unknown
          result_state: Database["public"]["Enums"]["grade_result_state"]
          school_id: string
          sequence: number
          upper_units: number
        }
        Insert: {
          created_at?: string
          created_by: string
          grade_scale_id: string
          id?: string
          label: string
          lower_units: number
          organization_id: string
          percentage_range?: unknown
          result_state: Database["public"]["Enums"]["grade_result_state"]
          school_id: string
          sequence: number
          upper_units: number
        }
        Update: {
          created_at?: string
          created_by?: string
          grade_scale_id?: string
          id?: string
          label?: string
          lower_units?: number
          organization_id?: string
          percentage_range?: unknown
          result_state?: Database["public"]["Enums"]["grade_result_state"]
          school_id?: string
          sequence?: number
          upper_units?: number
        }
        Relationships: [
          {
            foreignKeyName: "grade_scale_bands_organization_id_school_id_grade_scale_id_fkey"
            columns: ["organization_id", "school_id", "grade_scale_id"]
            isOneToOne: false
            referencedRelation: "grade_scales"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
        ]
      }
      grade_scales: {
        Row: {
          academic_year_id: string | null
          activated_at: string | null
          activated_by: string | null
          created_at: string
          created_by: string
          description: string | null
          id: string
          name: string
          organization_id: string
          retired_at: string | null
          retired_by: string | null
          school_id: string
          status: Database["public"]["Enums"]["grade_scale_status"]
          supersedes_grade_scale_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_year_id?: string | null
          activated_at?: string | null
          activated_by?: string | null
          created_at?: string
          created_by: string
          description?: string | null
          id?: string
          name: string
          organization_id: string
          retired_at?: string | null
          retired_by?: string | null
          school_id: string
          status?: Database["public"]["Enums"]["grade_scale_status"]
          supersedes_grade_scale_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_year_id?: string | null
          activated_at?: string | null
          activated_by?: string | null
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          name?: string
          organization_id?: string
          retired_at?: string | null
          retired_by?: string | null
          school_id?: string
          status?: Database["public"]["Enums"]["grade_scale_status"]
          supersedes_grade_scale_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "grade_scales_organization_id_school_id_academic_year_id_fkey"
            columns: ["organization_id", "school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "grade_scales_organization_id_school_id_fkey"
            columns: ["organization_id", "school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "grade_scales_organization_id_school_id_supersedes_grade_sc_fkey"
            columns: [
              "organization_id",
              "school_id",
              "supersedes_grade_scale_id",
            ]
            isOneToOne: false
            referencedRelation: "grade_scales"
            referencedColumns: ["organization_id", "school_id", "id"]
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
          status: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
      student_document_upload_intents: {
        Row: {
          consumed_at: string | null
          consumed_by: string | null
          created_at: string
          created_by: string
          expires_at: string
          id: string
          organization_id: string
          storage_path: string
          student_id: string
        }
        Insert: {
          consumed_at?: string | null
          consumed_by?: string | null
          created_at?: string
          created_by: string
          expires_at: string
          id?: string
          organization_id: string
          storage_path: string
          student_id: string
        }
        Update: {
          consumed_at?: string | null
          consumed_by?: string | null
          created_at?: string
          created_by?: string
          expires_at?: string
          id?: string
          organization_id?: string
          storage_path?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_document_upload_intents_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_document_upload_intents_organization_id_student_id_fkey"
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
          status: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
      student_enrollments: {
        Row: {
          academic_year_id: string
          correction_reason: string | null
          created_at: string
          created_by: string
          end_reason: string | null
          ended_on: string | null
          enrolled_on: string
          enrollment_range: unknown
          grade_level_id: string
          id: string
          organization_id: string
          scheduled_end_on: string
          school_id: string
          status: Database["public"]["Enums"]["enrollment_status"]
          student_id: string
          supersedes_enrollment_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_year_id: string
          correction_reason?: string | null
          created_at?: string
          created_by: string
          end_reason?: string | null
          ended_on?: string | null
          enrolled_on: string
          enrollment_range: unknown
          grade_level_id: string
          id?: string
          organization_id: string
          scheduled_end_on: string
          school_id: string
          status?: Database["public"]["Enums"]["enrollment_status"]
          student_id: string
          supersedes_enrollment_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_year_id?: string
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          end_reason?: string | null
          ended_on?: string | null
          enrolled_on?: string
          enrollment_range?: unknown
          grade_level_id?: string
          id?: string
          organization_id?: string
          scheduled_end_on?: string
          school_id?: string
          status?: Database["public"]["Enums"]["enrollment_status"]
          student_id?: string
          supersedes_enrollment_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_enrollments_organization_id_school_id_academic_yea_fkey"
            columns: ["organization_id", "school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_organization_id_school_id_grade_level__fkey"
            columns: ["organization_id", "school_id", "grade_level_id"]
            isOneToOne: false
            referencedRelation: "grade_levels"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_organization_id_supersedes_enrollment__fkey"
            columns: ["organization_id", "supersedes_enrollment_id"]
            isOneToOne: false
            referencedRelation: "student_enrollments"
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
          status: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
          status?: Database["public"]["Enums"]["record_status"]
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
      student_section_placements: {
        Row: {
          academic_year_id: string
          campus_id: string
          correction_reason: string | null
          created_at: string
          created_by: string
          end_reason: string | null
          ends_on: string | null
          id: string
          organization_id: string
          school_id: string
          section_id: string
          starts_on: string
          status: Database["public"]["Enums"]["section_placement_status"]
          student_enrollment_id: string
          student_id: string
          supersedes_placement_id: string | null
          transfer_to_placement_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_year_id: string
          campus_id: string
          correction_reason?: string | null
          created_at?: string
          created_by: string
          end_reason?: string | null
          ends_on?: string | null
          id?: string
          organization_id: string
          school_id: string
          section_id: string
          starts_on: string
          status?: Database["public"]["Enums"]["section_placement_status"]
          student_enrollment_id: string
          student_id: string
          supersedes_placement_id?: string | null
          transfer_to_placement_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_year_id?: string
          campus_id?: string
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          end_reason?: string | null
          ends_on?: string | null
          id?: string
          organization_id?: string
          school_id?: string
          section_id?: string
          starts_on?: string
          status?: Database["public"]["Enums"]["section_placement_status"]
          student_enrollment_id?: string
          student_id?: string
          supersedes_placement_id?: string | null
          transfer_to_placement_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_section_placements_organization_id_school_id_acade_fkey"
            columns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "student_enrollment_id",
            ]
            isOneToOne: false
            referencedRelation: "student_enrollments"
            referencedColumns: [
              "organization_id",
              "school_id",
              "academic_year_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "student_section_placements_organization_id_school_id_campu_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
            ]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "id",
            ]
          },
          {
            foreignKeyName: "student_section_placements_organization_id_supersedes_plac_fkey"
            columns: ["organization_id", "supersedes_placement_id"]
            isOneToOne: false
            referencedRelation: "student_section_placements"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "student_section_placements_organization_id_transfer_to_pla_fkey"
            columns: ["organization_id", "transfer_to_placement_id"]
            isOneToOne: false
            referencedRelation: "student_section_placements"
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
      teaching_assignments: {
        Row: {
          academic_year_id: string
          campus_id: string
          correction_reason: string | null
          created_at: string
          created_by: string
          effective_range: unknown
          end_reason: string | null
          ended_on: string | null
          id: string
          organization_id: string
          reassigned_to_assignment_id: string | null
          role: Database["public"]["Enums"]["teaching_assignment_role"]
          scheduled_ends_on: string
          school_id: string
          section_id: string
          staff_profile_id: string
          starts_on: string
          status: Database["public"]["Enums"]["teaching_assignment_status"]
          subject_id: string | null
          supersedes_assignment_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_year_id: string
          campus_id: string
          correction_reason?: string | null
          created_at?: string
          created_by: string
          effective_range: unknown
          end_reason?: string | null
          ended_on?: string | null
          id?: string
          organization_id: string
          reassigned_to_assignment_id?: string | null
          role: Database["public"]["Enums"]["teaching_assignment_role"]
          scheduled_ends_on: string
          school_id: string
          section_id: string
          staff_profile_id: string
          starts_on: string
          status?: Database["public"]["Enums"]["teaching_assignment_status"]
          subject_id?: string | null
          supersedes_assignment_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_year_id?: string
          campus_id?: string
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          effective_range?: unknown
          end_reason?: string | null
          ended_on?: string | null
          id?: string
          organization_id?: string
          reassigned_to_assignment_id?: string | null
          role?: Database["public"]["Enums"]["teaching_assignment_role"]
          scheduled_ends_on?: string
          school_id?: string
          section_id?: string
          staff_profile_id?: string
          starts_on?: string
          status?: Database["public"]["Enums"]["teaching_assignment_status"]
          subject_id?: string | null
          supersedes_assignment_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "teaching_assignments_organization_id_reassigned_to_assignm_fkey"
            columns: ["organization_id", "reassigned_to_assignment_id"]
            isOneToOne: false
            referencedRelation: "teaching_assignments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "teaching_assignments_organization_id_school_id_campus_id_a_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
            ]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "id",
            ]
          },
          {
            foreignKeyName: "teaching_assignments_organization_id_school_id_subject_id_fkey"
            columns: ["organization_id", "school_id", "subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "teaching_assignments_organization_id_staff_profile_id_fkey"
            columns: ["organization_id", "staff_profile_id"]
            isOneToOne: false
            referencedRelation: "staff_profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "teaching_assignments_organization_id_supersedes_assignment_fkey"
            columns: ["organization_id", "supersedes_assignment_id"]
            isOneToOne: false
            referencedRelation: "teaching_assignments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      term_grade_calculation_sources: {
        Row: {
          assessment_id: string
          assessment_result_id: string
          assessment_root_id: string
          assessment_student_id: string
          assessment_version_id: string
          assessment_weight: number
          created_at: string
          created_by: string
          effective_weight: number
          id: string
          maximum_score: number
          organization_id: string
          score: number
          score_ratio: number
          student_id: string
          term_grade_calculation_id: string
          weighted_points: number
        }
        Insert: {
          assessment_id: string
          assessment_result_id: string
          assessment_root_id: string
          assessment_student_id: string
          assessment_version_id: string
          assessment_weight: number
          created_at?: string
          created_by: string
          effective_weight: number
          id?: string
          maximum_score: number
          organization_id: string
          score: number
          score_ratio: number
          student_id: string
          term_grade_calculation_id: string
          weighted_points: number
        }
        Update: {
          assessment_id?: string
          assessment_result_id?: string
          assessment_root_id?: string
          assessment_student_id?: string
          assessment_version_id?: string
          assessment_weight?: number
          created_at?: string
          created_by?: string
          effective_weight?: number
          id?: string
          maximum_score?: number
          organization_id?: string
          score?: number
          score_ratio?: number
          student_id?: string
          term_grade_calculation_id?: string
          weighted_points?: number
        }
        Relationships: [
          {
            foreignKeyName: "term_grade_calculation_source_organization_id_assessment_i_fkey"
            columns: ["organization_id", "assessment_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "term_grade_calculation_source_organization_id_assessment_r_fkey"
            columns: ["organization_id", "assessment_result_id"]
            isOneToOne: false
            referencedRelation: "assessment_results"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "term_grade_calculation_source_organization_id_assessment_s_fkey"
            columns: ["organization_id", "assessment_student_id"]
            isOneToOne: false
            referencedRelation: "assessment_students"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "term_grade_calculation_source_organization_id_term_grade_c_fkey"
            columns: ["organization_id", "term_grade_calculation_id"]
            isOneToOne: false
            referencedRelation: "term_grade_calculations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "term_grade_sources_exact_calculation_fk"
            columns: [
              "organization_id",
              "term_grade_calculation_id",
              "student_id",
            ]
            isOneToOne: false
            referencedRelation: "term_grade_calculations"
            referencedColumns: ["organization_id", "id", "student_id"]
          },
          {
            foreignKeyName: "term_grade_sources_exact_result_fk"
            columns: [
              "organization_id",
              "assessment_id",
              "student_id",
              "assessment_student_id",
              "assessment_result_id",
            ]
            isOneToOne: false
            referencedRelation: "assessment_results"
            referencedColumns: [
              "organization_id",
              "assessment_id",
              "student_id",
              "assessment_student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grade_sources_exact_snapshot_fk"
            columns: [
              "organization_id",
              "assessment_id",
              "student_id",
              "assessment_student_id",
            ]
            isOneToOne: false
            referencedRelation: "assessment_students"
            referencedColumns: [
              "organization_id",
              "assessment_id",
              "student_id",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grade_sources_root_fk"
            columns: ["organization_id", "assessment_root_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "term_grade_sources_version_fk"
            columns: ["organization_id", "assessment_version_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      term_grade_calculations: {
        Row: {
          calculated_at: string
          calculated_by: string
          calculation_sequence: number
          contributing_assessment_count: number
          grade_label: string
          grade_scale_band_id: string
          grade_scale_id: string
          id: string
          organization_id: string
          raw_percentage: number
          result_state: Database["public"]["Enums"]["grade_result_state"]
          rounded_percentage: number
          student_id: string
          term_grade_record_id: string
          term_grade_set_id: string
          weight_total: number
        }
        Insert: {
          calculated_at?: string
          calculated_by: string
          calculation_sequence: number
          contributing_assessment_count: number
          grade_label: string
          grade_scale_band_id: string
          grade_scale_id: string
          id?: string
          organization_id: string
          raw_percentage: number
          result_state: Database["public"]["Enums"]["grade_result_state"]
          rounded_percentage: number
          student_id: string
          term_grade_record_id: string
          term_grade_set_id: string
          weight_total: number
        }
        Update: {
          calculated_at?: string
          calculated_by?: string
          calculation_sequence?: number
          contributing_assessment_count?: number
          grade_label?: string
          grade_scale_band_id?: string
          grade_scale_id?: string
          id?: string
          organization_id?: string
          raw_percentage?: number
          result_state?: Database["public"]["Enums"]["grade_result_state"]
          rounded_percentage?: number
          student_id?: string
          term_grade_record_id?: string
          term_grade_set_id?: string
          weight_total?: number
        }
        Relationships: [
          {
            foreignKeyName: "term_grade_calculations_exact_record_fk"
            columns: [
              "organization_id",
              "term_grade_set_id",
              "student_id",
              "calculation_sequence",
              "term_grade_record_id",
            ]
            isOneToOne: false
            referencedRelation: "term_grade_records"
            referencedColumns: [
              "organization_id",
              "term_grade_set_id",
              "student_id",
              "calculation_sequence",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grade_calculations_organization_id_grade_scale_id_gra_fkey"
            columns: [
              "organization_id",
              "grade_scale_id",
              "grade_scale_band_id",
            ]
            isOneToOne: false
            referencedRelation: "grade_scale_bands"
            referencedColumns: ["organization_id", "grade_scale_id", "id"]
          },
          {
            foreignKeyName: "term_grade_calculations_organization_id_term_grade_record__fkey"
            columns: ["organization_id", "term_grade_record_id"]
            isOneToOne: false
            referencedRelation: "term_grade_records"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      term_grade_records: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          calculation_sequence: number
          campus_id: string
          created_at: string
          created_by: string
          id: string
          organization_id: string
          school_id: string
          section_id: string
          student_id: string
          subject_id: string | null
          term_grade_set_id: string
          term_grading_configuration_id: string
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          calculation_sequence: number
          campus_id: string
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          school_id: string
          section_id: string
          student_id: string
          subject_id?: string | null
          term_grade_set_id: string
          term_grading_configuration_id: string
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          calculation_sequence?: number
          campus_id?: string
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          school_id?: string
          section_id?: string
          student_id?: string
          subject_id?: string | null
          term_grade_set_id?: string
          term_grading_configuration_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "term_grade_records_organization_id_school_id_campus_id_aca_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "term_grade_set_id",
            ]
            isOneToOne: false
            referencedRelation: "term_grade_sets"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grade_records_organization_id_student_id_fkey"
            columns: ["organization_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      term_grade_sets: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          calculation_sequence: number
          campus_id: string
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          correction_reason: string | null
          created_at: string
          created_by: string
          finalized_at: string | null
          finalized_by: string | null
          id: string
          lifecycle_status: Database["public"]["Enums"]["term_grade_lifecycle_status"]
          organization_id: string
          publication_state: Database["public"]["Enums"]["term_grade_publication_state"]
          published_at: string | null
          published_by: string | null
          school_id: string
          section_id: string
          source_fingerprint: string
          subject_id: string | null
          supersedes_term_grade_set_id: string | null
          term_grading_configuration_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          calculation_sequence?: number
          campus_id: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          correction_reason?: string | null
          created_at?: string
          created_by: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          lifecycle_status?: Database["public"]["Enums"]["term_grade_lifecycle_status"]
          organization_id: string
          publication_state?: Database["public"]["Enums"]["term_grade_publication_state"]
          published_at?: string | null
          published_by?: string | null
          school_id: string
          section_id: string
          source_fingerprint: string
          subject_id?: string | null
          supersedes_term_grade_set_id?: string | null
          term_grading_configuration_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          calculation_sequence?: number
          campus_id?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          correction_reason?: string | null
          created_at?: string
          created_by?: string
          finalized_at?: string | null
          finalized_by?: string | null
          id?: string
          lifecycle_status?: Database["public"]["Enums"]["term_grade_lifecycle_status"]
          organization_id?: string
          publication_state?: Database["public"]["Enums"]["term_grade_publication_state"]
          published_at?: string | null
          published_by?: string | null
          school_id?: string
          section_id?: string
          source_fingerprint?: string
          subject_id?: string | null
          supersedes_term_grade_set_id?: string | null
          term_grading_configuration_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "term_grade_sets_organization_id_school_id_campus_id_academ_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "term_grading_configuration_id",
            ]
            isOneToOne: false
            referencedRelation: "term_grading_configurations"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "academic_term_id",
              "section_id",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grade_sets_organization_id_supersedes_term_grade_set__fkey"
            columns: ["organization_id", "supersedes_term_grade_set_id"]
            isOneToOne: false
            referencedRelation: "term_grade_sets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      term_grading_configurations: {
        Row: {
          academic_term_id: string
          academic_year_id: string
          activated_at: string | null
          activated_by: string | null
          campus_id: string
          created_at: string
          created_by: string
          grade_scale_id: string
          id: string
          include_unpublished_finalized: boolean
          organization_id: string
          require_weights_total_100: boolean
          retired_at: string | null
          retired_by: string | null
          school_id: string
          section_id: string
          status: Database["public"]["Enums"]["term_grading_configuration_status"]
          subject_id: string | null
          supersedes_configuration_id: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          academic_term_id: string
          academic_year_id: string
          activated_at?: string | null
          activated_by?: string | null
          campus_id: string
          created_at?: string
          created_by: string
          grade_scale_id: string
          id?: string
          include_unpublished_finalized?: boolean
          organization_id: string
          require_weights_total_100?: boolean
          retired_at?: string | null
          retired_by?: string | null
          school_id: string
          section_id: string
          status?: Database["public"]["Enums"]["term_grading_configuration_status"]
          subject_id?: string | null
          supersedes_configuration_id?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          academic_term_id?: string
          academic_year_id?: string
          activated_at?: string | null
          activated_by?: string | null
          campus_id?: string
          created_at?: string
          created_by?: string
          grade_scale_id?: string
          id?: string
          include_unpublished_finalized?: boolean
          organization_id?: string
          require_weights_total_100?: boolean
          retired_at?: string | null
          retired_by?: string | null
          school_id?: string
          section_id?: string
          status?: Database["public"]["Enums"]["term_grading_configuration_status"]
          subject_id?: string | null
          supersedes_configuration_id?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "term_grading_configurations_organization_id_academic_year__fkey"
            columns: ["organization_id", "academic_year_id", "academic_term_id"]
            isOneToOne: false
            referencedRelation: "academic_terms"
            referencedColumns: ["organization_id", "academic_year_id", "id"]
          },
          {
            foreignKeyName: "term_grading_configurations_organization_id_school_id_camp_fkey"
            columns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "section_id",
            ]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: [
              "organization_id",
              "school_id",
              "campus_id",
              "academic_year_id",
              "id",
            ]
          },
          {
            foreignKeyName: "term_grading_configurations_organization_id_school_id_grad_fkey"
            columns: ["organization_id", "school_id", "grade_scale_id"]
            isOneToOne: false
            referencedRelation: "grade_scales"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "term_grading_configurations_organization_id_school_id_subj_fkey"
            columns: ["organization_id", "school_id", "subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["organization_id", "school_id", "id"]
          },
          {
            foreignKeyName: "term_grading_configurations_organization_id_supersedes_con_fkey"
            columns: ["organization_id", "supersedes_configuration_id"]
            isOneToOne: false
            referencedRelation: "term_grading_configurations"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      activate_grade_scale: { Args: { id: string }; Returns: string }
      activate_term_grading_configuration: {
        Args: { id: string }
        Returns: string
      }
      archive_attendance_absence_reason: {
        Args: { id: string }
        Returns: string
      }
      archive_building: { Args: { id: string }; Returns: string }
      archive_grade_level: { Args: { id: string }; Returns: string }
      archive_guardian: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_room: { Args: { id: string }; Returns: string }
      archive_section: { Args: { p_id: string }; Returns: string }
      archive_section_v0_8_impl: { Args: { id: string }; Returns: string }
      archive_staff_profile: { Args: { id: string }; Returns: string }
      archive_student: {
        Args: { archive_reason: string; target_student_id: string }
        Returns: string
      }
      archive_student_address: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_student_document: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_student_emergency_contact: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_student_guardian: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_student_identifier: {
        Args: { archive_reason: string; id: string }
        Returns: string
      }
      archive_subject: { Args: { id: string }; Returns: string }
      calculate_term_grades: {
        Args: { term_grading_configuration_id: string }
        Returns: {
          grade_count: number
          term_grade_set_id: string
        }[]
      }
      cancel_draft_assessment: {
        Args: { cancellation_reason: string; id: string }
        Returns: string
      }
      cancel_draft_term_grades: {
        Args: { cancellation_reason: string; term_grade_set_id: string }
        Returns: string
      }
      complete_student_enrollment: {
        Args: { ended_on: string; id: string; reason: string }
        Returns: string
      }
      complete_student_section_placement: {
        Args: { ended_on: string; id: string; reason: string }
        Returns: string
      }
      correct_assessment: {
        Args: {
          correction_reason: string
          id: string
          replacement_assessment_date: string
          replacement_assessment_type: Database["public"]["Enums"]["assessment_type"]
          replacement_description: string
          replacement_due_date: string
          replacement_maximum_score: number
          replacement_results: Database["public"]["CompositeTypes"]["assessment_result_input"][]
          replacement_subject_id: string
          replacement_title: string
          replacement_weight: number
        }
        Returns: {
          corrected_assessment_id: string
          replacement_assessment_id: string
        }[]
      }
      correct_attendance_session: {
        Args: {
          correction_reason: string
          id: string
          marks: Database["public"]["CompositeTypes"]["attendance_mark_input"][]
        }
        Returns: {
          corrected_session_id: string
          replacement_session_id: string
        }[]
      }
      correct_student_enrollment: {
        Args: {
          correction_reason: string
          create_replacement: boolean
          id: string
          replacement_academic_year_id: string
          replacement_end_reason: string
          replacement_ended_on: string
          replacement_enrolled_on: string
          replacement_grade_level_id: string
          replacement_status: Database["public"]["Enums"]["enrollment_status"]
        }
        Returns: {
          corrected_enrollment_id: string
          replacement_enrollment_id: string
        }[]
      }
      correct_student_section_placement: {
        Args: {
          correction_reason: string
          create_replacement: boolean
          id: string
          replacement_end_reason: string
          replacement_ends_on: string
          replacement_section_id: string
          replacement_starts_on: string
          replacement_status: Database["public"]["Enums"]["section_placement_status"]
        }
        Returns: {
          corrected_placement_id: string
          replacement_placement_id: string
        }[]
      }
      correct_teaching_assignment: {
        Args: {
          correction_reason: string
          create_replacement: boolean
          id: string
          replacement_role: Database["public"]["Enums"]["teaching_assignment_role"]
          replacement_scheduled_ends_on: string
          replacement_section_id: string
          replacement_staff_profile_id: string
          replacement_starts_on: string
          replacement_subject_id: string
        }
        Returns: {
          corrected_assignment_id: string
          replacement_assignment_id: string
        }[]
      }
      correct_term_grades: {
        Args: { correction_reason: string; term_grade_set_id: string }
        Returns: {
          corrected_term_grade_set_id: string
          replacement_term_grade_set_id: string
        }[]
      }
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
      create_assessment: {
        Args: {
          academic_term_id: string
          assessment_date: string
          assessment_type: Database["public"]["Enums"]["assessment_type"]
          description: string
          due_date: string
          maximum_score: number
          section_id: string
          subject_id: string
          title: string
          weight: number
        }
        Returns: string
      }
      create_attendance_absence_reason: {
        Args: {
          campus_id: string
          code: string
          description: string
          name: string
          school_id: string
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
      create_grade_scale: {
        Args: {
          academic_year_id: string
          bands: Database["public"]["CompositeTypes"]["grade_scale_band_input"][]
          description: string
          name: string
          school_id: string
        }
        Returns: string
      }
      create_guardian_for_student: {
        Args: {
          alternate_phone: string
          email: string
          financial_responsibility: boolean
          first_name: string
          has_portal_access: boolean
          is_primary: boolean
          last_name: string
          middle_name: string
          occupation: string
          phone: string
          pickup_authorized: boolean
          preferred_language: string
          receives_academic_updates: boolean
          receives_attendance_alerts: boolean
          relationship_type: string
          student_id: string
        }
        Returns: {
          guardian_id: string
          student_guardian_id: string
        }[]
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
      create_student: {
        Args: {
          admission_date: string
          campus_id: string
          date_of_birth: string
          exit_date: string
          first_name: string
          gender: string
          last_name: string
          middle_name: string
          nationality_code: string
          photo_path: string
          preferred_name: string
          primary_language: string
          school_id: string
          status?: Database["public"]["Enums"]["record_status"]
          student_number: string
        }
        Returns: string
      }
      create_student_address: {
        Args: {
          address_type: string
          city: string
          country_code: string
          is_primary: boolean
          line_1: string
          line_2: string
          postal_code: string
          state_region: string
          status?: Database["public"]["Enums"]["record_status"]
          student_id: string
        }
        Returns: string
      }
      create_student_document: {
        Args: {
          document_type: string
          expires_at: string
          file_size: number
          issued_at: string
          mime_type: string
          status?: Database["public"]["Enums"]["record_status"]
          title: string
          upload_intent_id: string
          visibility: Database["public"]["Enums"]["student_document_visibility"]
        }
        Returns: string
      }
      create_student_emergency_contact: {
        Args: {
          alternate_phone: string
          guardian_id: string
          name: string
          phone: string
          priority: number
          relationship: string
          status?: Database["public"]["Enums"]["record_status"]
          student_id: string
        }
        Returns: string
      }
      create_student_identifier: {
        Args: {
          country_code: string
          expires_at: string
          identifier_type: string
          identifier_value: string
          issued_at: string
          status?: Database["public"]["Enums"]["record_status"]
          student_id: string
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
      create_teaching_assignment: {
        Args: {
          role: Database["public"]["Enums"]["teaching_assignment_role"]
          scheduled_ends_on: string
          section_id: string
          staff_profile_id: string
          starts_on: string
          subject_id: string
        }
        Returns: string
      }
      create_term_grading_configuration: {
        Args: {
          academic_term_id: string
          grade_scale_id: string
          include_unpublished_finalized: boolean
          require_weights_total_100: boolean
          section_id: string
          subject_id: string
        }
        Returns: string
      }
      end_teaching_assignment: {
        Args: { ended_on: string; id: string; reason: string }
        Returns: string
      }
      enroll_student: {
        Args: {
          academic_year_id: string
          enrolled_on: string
          grade_level_id: string
          student_id: string
        }
        Returns: string
      }
      finalize_assessment: { Args: { id: string }; Returns: string }
      finalize_attendance_session: { Args: { id: string }; Returns: string }
      finalize_term_grades: {
        Args: { term_grade_set_id: string }
        Returns: string
      }
      link_guardian_to_student: {
        Args: {
          financial_responsibility: boolean
          guardian_id: string
          has_portal_access: boolean
          is_primary: boolean
          pickup_authorized: boolean
          receives_academic_updates: boolean
          receives_attendance_alerts: boolean
          relationship_type: string
          student_id: string
        }
        Returns: string
      }
      open_attendance_session: {
        Args: { section_id: string; session_date: string }
        Returns: string
      }
      place_student_in_section: {
        Args: {
          section_id: string
          starts_on: string
          student_enrollment_id: string
        }
        Returns: string
      }
      publish_assessment: { Args: { id: string }; Returns: string }
      publish_term_grades: {
        Args: { term_grade_set_id: string }
        Returns: string
      }
      reassign_teaching_assignment: {
        Args: {
          id: string
          reason: string
          reassign_on: string
          replacement_role: Database["public"]["Enums"]["teaching_assignment_role"]
          replacement_scheduled_ends_on: string
          replacement_staff_profile_id: string
        }
        Returns: {
          from_assignment_id: string
          to_assignment_id: string
        }[]
      }
      recalculate_draft_term_grades: {
        Args: { id: string }
        Returns: {
          calculation_sequence: number
          grade_count: number
          term_grade_set_id: string
        }[]
      }
      record_assessment_results: {
        Args: {
          id: string
          results: Database["public"]["CompositeTypes"]["assessment_result_input"][]
        }
        Returns: string
      }
      retire_grade_scale: { Args: { id: string }; Returns: string }
      retire_term_grading_configuration: {
        Args: { id: string }
        Returns: string
      }
      revise_grade_scale: {
        Args: {
          id: string
          replacement_bands: Database["public"]["CompositeTypes"]["grade_scale_band_input"][]
          replacement_description: string
          replacement_name: string
        }
        Returns: string
      }
      revise_term_grading_configuration: {
        Args: {
          id: string
          replacement_grade_scale_id: string
          replacement_include_unpublished_finalized: boolean
          replacement_require_weights_total_100: boolean
        }
        Returns: string
      }
      submit_attendance_session: {
        Args: {
          id: string
          marks: Database["public"]["CompositeTypes"]["attendance_mark_input"][]
        }
        Returns: string
      }
      transfer_student_section: {
        Args: {
          destination_section_id: string
          id: string
          reason: string
          transfer_on: string
        }
        Returns: {
          from_placement_id: string
          to_placement_id: string
        }[]
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
      update_assessment: {
        Args: {
          assessment_type: Database["public"]["Enums"]["assessment_type"]
          description: string
          due_date: string
          id: string
          set_description?: boolean
          set_due_date?: boolean
          title: string
        }
        Returns: string
      }
      update_attendance_absence_reason: {
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
      update_draft_grade_scale: {
        Args: {
          bands: Database["public"]["CompositeTypes"]["grade_scale_band_input"][]
          description: string
          id: string
          name: string
          set_description: boolean
        }
        Returns: string
      }
      update_draft_term_grading_configuration: {
        Args: {
          grade_scale_id: string
          id: string
          include_unpublished_finalized: boolean
          require_weights_total_100: boolean
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
      update_guardian: {
        Args: {
          alternate_phone: string
          email: string
          first_name: string
          id: string
          last_name: string
          middle_name: string
          occupation: string
          phone: string
          preferred_language: string
          set_alternate_phone: boolean
          set_email: boolean
          set_middle_name: boolean
          set_occupation: boolean
          set_phone: boolean
          set_preferred_language: boolean
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
      update_section_v0_8_impl: {
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
      update_student: {
        Args: {
          admission_date: string
          campus_id: string
          date_of_birth: string
          exit_date: string
          first_name: string
          gender: string
          id: string
          last_name: string
          middle_name: string
          nationality_code: string
          photo_path: string
          preferred_name: string
          primary_language: string
          school_id: string
          set_admission_date: boolean
          set_campus_id: boolean
          set_exit_date: boolean
          set_gender: boolean
          set_middle_name: boolean
          set_nationality_code: boolean
          set_photo_path: boolean
          set_preferred_name: boolean
          set_primary_language: boolean
          set_school_id: boolean
          status: Database["public"]["Enums"]["record_status"]
          student_number: string
        }
        Returns: string
      }
      update_student_address: {
        Args: {
          address_type: string
          city: string
          country_code: string
          id: string
          is_primary: boolean
          line_1: string
          line_2: string
          postal_code: string
          set_line_2: boolean
          set_postal_code: boolean
          set_state_region: boolean
          state_region: string
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_student_document: {
        Args: {
          document_type: string
          expires_at: string
          file_size: number
          id: string
          issued_at: string
          mime_type: string
          set_expires_at: boolean
          set_file_size: boolean
          set_issued_at: boolean
          set_mime_type: boolean
          status: Database["public"]["Enums"]["record_status"]
          title: string
          visibility: Database["public"]["Enums"]["student_document_visibility"]
        }
        Returns: string
      }
      update_student_emergency_contact: {
        Args: {
          alternate_phone: string
          guardian_id: string
          id: string
          name: string
          phone: string
          priority: number
          relationship: string
          set_alternate_phone: boolean
          set_guardian_id: boolean
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_student_guardian: {
        Args: {
          financial_responsibility: boolean
          has_portal_access: boolean
          id: string
          is_primary: boolean
          pickup_authorized: boolean
          receives_academic_updates: boolean
          receives_attendance_alerts: boolean
          relationship_type: string
          status: Database["public"]["Enums"]["record_status"]
        }
        Returns: string
      }
      update_student_identifier: {
        Args: {
          country_code: string
          expires_at: string
          id: string
          identifier_type: string
          identifier_value: string
          issued_at: string
          set_country_code: boolean
          set_expires_at: boolean
          set_issued_at: boolean
          status: Database["public"]["Enums"]["record_status"]
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
      withdraw_student_enrollment: {
        Args: { ended_on: string; id: string; reason: string }
        Returns: string
      }
      withdraw_student_section_placement: {
        Args: { ended_on: string; id: string; reason: string }
        Returns: string
      }
    }
    Enums: {
      academic_period_status: "draft" | "active" | "closed" | "archived"
      assessment_lifecycle_status:
        | "draft"
        | "finalized"
        | "corrected"
        | "cancelled"
      assessment_publication_state: "unpublished" | "published"
      assessment_type:
        | "assignment"
        | "quiz"
        | "exam"
        | "project"
        | "participation"
      attendance_mark_status: "present" | "absent" | "late" | "excused"
      attendance_session_status:
        | "open"
        | "submitted"
        | "finalized"
        | "corrected"
      enrollment_status: "active" | "withdrawn" | "completed" | "corrected"
      grade_result_state: "pass" | "fail"
      grade_scale_status: "draft" | "active" | "retired"
      membership_status: "invited" | "active" | "suspended" | "left"
      outbox_status: "pending" | "processing" | "processed" | "failed"
      record_status: "active" | "inactive" | "archived"
      role_assignment_status: "active" | "inactive"
      section_placement_status:
        | "active"
        | "withdrawn"
        | "completed"
        | "transferred"
        | "corrected"
      student_document_visibility:
        | "admin_only"
        | "staff"
        | "guardian"
        | "student"
      teaching_assignment_role:
        | "lead"
        | "co_teacher"
        | "assistant"
        | "substitute"
      teaching_assignment_status:
        | "active"
        | "ended"
        | "reassigned"
        | "corrected"
      term_grade_lifecycle_status:
        | "draft"
        | "finalized"
        | "corrected"
        | "cancelled"
      term_grade_publication_state: "unpublished" | "published"
      term_grading_configuration_status: "draft" | "active" | "retired"
    }
    CompositeTypes: {
      assessment_result_input: {
        student_id: string | null
        score: number | null
        teacher_comment: string | null
      }
      attendance_mark_input: {
        student_id: string | null
        mark: Database["public"]["Enums"]["attendance_mark_status"] | null
        arrival_time: string | null
        absence_reason_id: string | null
        note: string | null
      }
      grade_scale_band_input: {
        sequence: number | null
        lower_bound: number | null
        upper_bound: number | null
        label: string | null
        result_state: Database["public"]["Enums"]["grade_result_state"] | null
      }
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
      assessment_lifecycle_status: [
        "draft",
        "finalized",
        "corrected",
        "cancelled",
      ],
      assessment_publication_state: ["unpublished", "published"],
      assessment_type: [
        "assignment",
        "quiz",
        "exam",
        "project",
        "participation",
      ],
      attendance_mark_status: ["present", "absent", "late", "excused"],
      attendance_session_status: [
        "open",
        "submitted",
        "finalized",
        "corrected",
      ],
      enrollment_status: ["active", "withdrawn", "completed", "corrected"],
      grade_result_state: ["pass", "fail"],
      grade_scale_status: ["draft", "active", "retired"],
      membership_status: ["invited", "active", "suspended", "left"],
      outbox_status: ["pending", "processing", "processed", "failed"],
      record_status: ["active", "inactive", "archived"],
      role_assignment_status: ["active", "inactive"],
      section_placement_status: [
        "active",
        "withdrawn",
        "completed",
        "transferred",
        "corrected",
      ],
      student_document_visibility: [
        "admin_only",
        "staff",
        "guardian",
        "student",
      ],
      teaching_assignment_role: [
        "lead",
        "co_teacher",
        "assistant",
        "substitute",
      ],
      teaching_assignment_status: [
        "active",
        "ended",
        "reassigned",
        "corrected",
      ],
      term_grade_lifecycle_status: [
        "draft",
        "finalized",
        "corrected",
        "cancelled",
      ],
      term_grade_publication_state: ["unpublished", "published"],
      term_grading_configuration_status: ["draft", "active", "retired"],
    },
  },
} as const
