-- supabase/seed.sql
-- Sample data for testing your Supabase instance

-- Insert sample profiles (these will be created when users sign up via triggers)
-- This is just for reference/testing

-- Sample posts data
INSERT INTO public.posts (id, title, content, author_id, published) VALUES
('123e4567-e89b-12d3-a456-426614174000', 'Welcome to Supabase', 'This is a sample post to demonstrate the blogging functionality.', '123e4567-e89b-12d3-a456-426614174001', true),
('123e4567-e89b-12d3-a456-426614174002', 'Getting Started with Edge Functions', 'Learn how to create serverless functions with Supabase Edge Functions.', '123e4567-e89b-12d3-a456-426614174001', true),
('123e4567-e89b-12d3-a456-426614174003', 'Draft Post', 'This is a draft post that is not published yet.', '123e4567-e89b-12d3-a456-426614174001', false)
ON CONFLICT (id) DO NOTHING;

-- Sample comments data
INSERT INTO public.comments (id, content, author_id, post_id) VALUES
('223e4567-e89b-12d3-a456-426614174000', 'Great introduction to Supabase!', '123e4567-e89b-12d3-a456-426614174002', '123e4567-e89b-12d3-a456-426614174000'),
('223e4567-e89b-12d3-a456-426614174001', 'Looking forward to more tutorials like this.', '123e4567-e89b-12d3-a456-426614174002', '123e4567-e89b-12d3-a456-426614174000'),
('223e4567-e89b-12d3-a456-426614174002', 'Edge Functions are amazing for serverless development!', '123e4567-e89b-12d3-a456-426614174001', '123e4567-e89b-12d3-a456-426614174002')
ON CONFLICT (id) DO NOTHING;

-- Insert sample data for testing storage and other features
-- Create some test categories or tags if needed
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#3B82F6'
);

INSERT INTO public.categories (name, description, color) VALUES
('Technology', 'Posts about technology and programming', '#3B82F6'),
('Tutorials', 'Step-by-step guides and tutorials', '#10B981'),
('News', 'Latest news and updates', '#F59E0B'),
('General', 'General discussions and thoughts', '#6B7280')
ON CONFLICT (name) DO NOTHING;

-- Create a junction table for post categories
CREATE TABLE IF NOT EXISTS public.post_categories (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, category_id)
);

-- Add some categories to posts
INSERT INTO public.post_categories (post_id, category_id) 
SELECT p.id, c.id 
FROM public.posts p, public.categories c 
WHERE p.title = 'Welcome to Supabase' AND c.name = 'General'
ON CONFLICT DO NOTHING;

INSERT INTO public.post_categories (post_id, category_id) 
SELECT p.id, c.id 
FROM public.posts p, public.categories c 
WHERE p.title = 'Getting Started with Edge Functions' AND c.name = 'Tutorials'
ON CONFLICT DO NOTHING;

-- Create a simple analytics table for tracking
CREATE TABLE IF NOT EXISTS public.post_views (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    ip_address INET,
    user_agent TEXT
);

-- Insert some sample view data
INSERT INTO public.post_views (post_id, ip_address, user_agent) VALUES
((SELECT id FROM public.posts WHERE title = 'Welcome to Supabase'), '192.168.1.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
((SELECT id FROM public.posts WHERE title = 'Welcome to Supabase'), '192.168.1.2', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15'),
((SELECT id FROM public.posts WHERE title = 'Getting Started with Edge Functions'), '192.168.1.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
ON CONFLICT DO NOTHING;

-- Enable RLS on new tables
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;

-- Create policies for new tables
CREATE POLICY "Categories are viewable by everyone" ON public.categories
    FOR SELECT USING (true);

CREATE POLICY "Post categories are viewable by everyone" ON public.post_categories
    FOR SELECT USING (true);

CREATE POLICY "Post views are viewable by everyone" ON public.post_views
    FOR SELECT USING (true);

CREATE POLICY "Anyone can insert post views" ON public.post_views
    FOR INSERT WITH CHECK (true);

-- Create some useful views
CREATE OR REPLACE VIEW public.post_stats AS
SELECT 
    p.id,
    p.title,
    p.created_at,
    p.published,
    COUNT(c.id) as comment_count,
    COUNT(pv.id) as view_count
FROM public.posts p
LEFT JOIN public.comments c ON p.id = c.post_id
LEFT JOIN public.post_views pv ON p.id = pv.post_id
GROUP BY p.id, p.title, p.created_at, p.published;

-- Grant permissions on new objects
GRANT SELECT ON public.categories TO anon, authenticated;
GRANT SELECT ON public.post_categories TO anon, authenticated;
GRANT SELECT, INSERT ON public.post_views TO anon, authenticated;
GRANT SELECT ON public.post_stats TO anon, authenticated;

-- Create some helpful functions
CREATE OR REPLACE FUNCTION public.get_popular_posts(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    view_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.created_at,
        COUNT(pv.id)::BIGINT as view_count
    FROM public.posts p
    LEFT JOIN public.post_views pv ON p.id = pv.post_id
    WHERE p.published = true
    GROUP BY p.id, p.title, p.created_at
    ORDER BY view_count DESC, p.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.get_popular_posts TO anon, authenticated;