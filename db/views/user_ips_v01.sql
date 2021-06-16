SELECT
  user_id,
  ip,
  max(used_at) AS used_at
FROM (
  SELECT
    id AS user_id,
    sign_up_ip AS ip,
    created_at AS used_at
  FROM users
  WHERE sign_up_ip IS NOT NULL
  UNION ALL
  SELECT
    user_id,
    ip,
    updated_at
  FROM session_activations
  UNION ALL
  SELECT
    user_id,
    ip,
    created_at
  FROM login_activities
  WHERE success = 't'
) AS t0
GROUP BY user_id, ip
