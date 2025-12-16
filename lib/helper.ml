open Base

let timestamp_to_iso_string time_float =
  let sec = time_float /. 1000.0 in
  let tm = Unix.gmtime sec in
  Printf.sprintf
    "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.tm_year + 1900)
    (tm.tm_mon + 1)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec
;;

let tm_of_utc tm_year tm_mon tm_mday tm_hour tm_min tm_sec =
  (* Convert UTC time components to Unix timestamp *)
  (* Using formula that counts complete days from 1970-01-01 *)
  let days_in_month = [| 31; 28; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31 |] in
  let is_leap_year year = (Int.(year % 4 = 0) && Int.(year % 100 <> 0)) || Int.(year % 400 = 0) in
  
  let year = tm_year + 1900 in
  
  (* Count days from years 1970 to year-1 *)
  let days_from_complete_years =
    let rec count_days y acc =
      if y >= year then acc
      else
        let days = if is_leap_year y then 366 else 365 in
        count_days (y + 1) (acc + days)
    in
    count_days 1970 0
  in
  
  (* Count days from months in the current year *)
  let days_from_months =
    let month_days = Array.copy days_in_month in
    if is_leap_year year then month_days.(1) <- 29;
    let rec count_days m acc =
      if m >= tm_mon then acc
      else count_days (m + 1) (acc + month_days.(m))
    in
    count_days 0 0
  in
  
  (* Day of month is 1-indexed, so subtract 1 *)
  let total_days = days_from_complete_years + days_from_months + (tm_mday - 1) in
  let total_seconds = total_days * 86400 + tm_hour * 3600 + tm_min * 60 + tm_sec in
  Float.of_int total_seconds
;;

let time_string_to_float time_str =
  (* Remove trailing Z if present *)
  let normalized =
    if String.is_suffix time_str ~suffix:"Z"
    then String.sub time_str ~pos:0 ~len:(String.length time_str - 1)
    else time_str
  in
  (* Check if it contains date and time separated by T *)
  let date_part, time_part =
    if String.contains normalized 'T'
    then (
      match String.split normalized ~on:'T' with
      | [ d; t ] -> Some d, Some t
      | _ -> None, None)
    else if String.contains normalized '-' && not (String.contains normalized ':')
    then
      (* Just date *)
      Some normalized, None
    else
      (* Just time *)
      None, Some normalized
  in
  (* Parse date component - default to all zeros if not present *)
  let tm_year, tm_mon, tm_mday =
    match date_part with
    | Some date_str ->
      (match String.split date_str ~on:'-' with
       | [ year_str; month_str; day_str ] ->
         Int.of_string year_str - 1900, Int.of_string month_str - 1, Int.of_string day_str
       | _ -> 70, 0, 1)
      (* Default to 1970-01-01 *)
    | None -> 70, 0, 1 (* Default to 1970-01-01 *)
  in
  (* Parse time component *)
  let tm_hour, tm_min, tm_sec =
    match time_part with
    | Some time_str ->
      let parts = String.split time_str ~on:':' in
      (match List.map parts ~f:Int.of_string with
       | [ hours; minutes ] -> hours, minutes, 0
       | [ hours; minutes; seconds ] -> hours, minutes, seconds
       | _ -> 0, 0, 0)
    | None -> 0, 0, 0
  in
  tm_of_utc tm_year tm_mon tm_mday tm_hour tm_min tm_sec *. 1000.0
;;
