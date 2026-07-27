/*
 * 8-Week Challenge - shared authentication helpers
 *
 * These functions wrap Supabase Auth and the `profiles` table used to store
 * challenge-specific data (name, tier, payment status, admin flag, etc.).
 */

(function () {
  const client = window.sb;

  async function signUp(email, password, profileData) {
    const { data, error } = await client.auth.signUp({
      email,
      password,
      options: { data: profileData }
    });
    if (error) throw error;

    // Create the profile row immediately if the auth call returned a user.
    if (data.user) {
      const { error: profileError } = await client
        .from('profiles')
        .upsert({
          id: data.user.id,
          email: email,
          full_name: profileData.full_name,
          phone: profileData.phone || null,
          tier: profileData.tier,
          starting_weight_kg: profileData.starting_weight_kg || null,
          age: profileData.age || null,
          paid: profileData.paid === true,
          is_admin: false,
          challenge_id: null,
          referral_code: profileData.own_referral_code || null,
          referred_by: profileData.referred_by || null
        }, { onConflict: 'id' });

      if (profileError) {
        console.error('Profile upsert error:', profileError);
        // Don't throw here - auth succeeded; trigger also creates a basic profile as fallback.
      }
    }

    return data;
  }

  async function signIn(email, password) {
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  }

  async function signOut() {
    const { error } = await client.auth.signOut();
    if (error) throw error;
  }

  async function getSession() {
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    return data.session;
  }

  async function getUser() {
    const session = await getSession();
    return session?.user || null;
  }

  async function getProfile(userId) {
    if (!userId) {
      const user = await getUser();
      if (!user) return null;
      userId = user.id;
    }
    const { data, error } = await client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();
    if (error) {
      console.error('getProfile error:', error);
      return null;
    }
    return data;
  }

  async function updateProfile(updates) {
    const user = await getUser();
    if (!user) throw new Error('Not signed in');
    const { data, error } = await client
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();
    if (error) throw error;
    return data;
  }

  async function markPaid(userId) {
    if (!userId) {
      const user = await getUser();
      userId = user?.id;
    }
    if (!userId) throw new Error('No user to mark paid');
    const { data, error } = await client
      .from('profiles')
      .update({ paid: true })
      .eq('id', userId)
      .select()
      .single();
    if (error) throw error;
    return data;
  }

  async function requireAuth(redirectTo) {
    const session = await getSession();
    if (!session) {
      const target = redirectTo || window.location.pathname;
      window.location.href = 'login.html?redirect=' + encodeURIComponent(target);
      return null;
    }
    return session.user;
  }

  async function requireAdmin() {
    const user = await requireAuth('admin.html');
    const profile = await getProfile(user.id);
    if (!profile || !profile.is_admin) {
      window.location.href = 'dashboard.html';
      return null;
    }
    return { user, profile };
  }

  function onAuthStateChange(callback) {
    return client.auth.onAuthStateChange(callback);
  }

  window.auth = {
    signUp,
    signIn,
    signOut,
    getSession,
    getUser,
    getProfile,
    updateProfile,
    markPaid,
    requireAuth,
    requireAdmin,
    onAuthStateChange
  };
})();
