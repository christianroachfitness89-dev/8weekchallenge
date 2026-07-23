/*
 * 8-Week Challenge — Supabase client configuration
 *
 * Replace the placeholders below with your own Supabase project URL and
 * anon/public key after creating the project (see SETUP.md).
 *
 * This file is loaded on every page so we only configure the client once.
 */

const SUPABASE_URL = 'https://dcijyztwrrxmymbhfcwp.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRjaWp5enR3cnJ4bXltYmhmY3dwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2ODk0MzAsImV4cCI6MjEwMDI2NTQzMH0.pa8HmU8dQsvzHB3-S_nqyOW7MEznxE1f-8C0y1BTo2k';

let _client = null;

function getSupabaseClient() {
  if (_client) return _client;

  if (typeof supabase === 'undefined' || !supabase.createClient) {
    throw new Error(
      'Supabase client library not loaded. Make sure the CDN script is included before supabase-client.js.'
    );
  }

  if (SUPABASE_URL.includes('YOUR_PROJECT_ID') || SUPABASE_ANON_KEY.includes('YOUR_SUPABASE_ANON_KEY')) {
    console.warn('Supabase credentials are still placeholders — update supabase-client.js before deploying.');
  }

  _client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true
    }
  });

  return _client;
}

// Expose a global alias for every page.
window.sb = getSupabaseClient();
