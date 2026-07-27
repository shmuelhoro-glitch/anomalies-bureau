import { createClient } from "@supabase/supabase-js";
import "dotenv/config"

const supabase = await createClient(process.env.SUPABASE_URL, process.env.SUPABASE_PUBLISHABLE_KEY)

export default supabase



