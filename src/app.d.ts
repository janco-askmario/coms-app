import type { Session, SupabaseClient, User } from '@supabase/supabase-js';

export type Profile = {
	id: string;
	email: string;
	full_name: string | null;
	role: 'admin' | 'member';
	approved: boolean;
};

declare global {
	namespace App {
		interface Locals {
			supabase: SupabaseClient;
			safeGetSession: () => Promise<{ session: Session | null; user: User | null }>;
			user: User | null;
			profile: Profile | null;
		}
	}
}

export {};
