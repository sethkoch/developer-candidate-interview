# I went with more of a functional programming approach because I'm brand new to Ruby and I'm coming from JavaScript.  Most of the code is all helper
#functions.  I believe this is not the best way to do it, but my goal was to build something that works and wasn't too horrible to read.  
# This is only the second thing I've written in Ruby, the first was the palindrome finder.  
#I chose to not list every conflict.  Say for example an input row calls for a teacher that doesn't exist.  I find the only relevant 
#error is that the teacher doesn't exist.  So, I've attempted to list all the relevant conflicts from each row. 

require 'csv'    
require 'time'

# global variables

# convert csv data to array and downcase names
#global variable = $ia
ia_text = File.read('instructor_availability.csv')
$ia = CSV.parse(ia_text, :headers => true)
$ia.each_with_index do |row, i|
  $ia[i][0] = $ia[i][0].downcase
  $ia[i][2] = $ia[i][2].to_i
end

# will act as api request, down case names after converting csv data to array
#global variable = $request
request_text = File.read('input.csv')
$request = CSV.parse(request_text, :headers => true)
$request.each_with_index do |row, i|
  $request[i][7] = $request[i][7].downcase
end

$teacherscourses = {
  "counter" => 1
}
$studentscourses = {
  "counter" => 1
}
$conflicts = []
# updates each api iteration and hold courses that match teacher and training type
$matchingCourseTypes = nil
#used to track exact course matches for both private and group courses below
$noMatch = nil

# end global variables

# helper functions

def setTeachersCourses(teachersname, maxparticipants, trainingtype, startdate, enddate, starttime, endtime)
  if $teacherscourses[teachersname] == nil
    $teacherscourses[teachersname] = {}
  end
  $teacherscourses[teachersname]["course#{$teacherscourses["counter"]}"] = {}
  course = $teacherscourses[teachersname]["course#{$teacherscourses["counter"]}"]
  course["teachersname"] = teachersname
  course["maxparticipants"] = maxparticipants
  course["trainingtype"] = trainingtype
  course["startdate"] = startdate
  course["enddate"] = enddate
  course["starttime"] = starttime
  course["endtime"] = endtime
  course["maxparticipants"] -= 1
  $teacherscourses["counter"] += 1
end

def teacherCoursesConflictChecker(starttime, endtime, startdate, enddate, teachersname, id)
  # there is not currently a matching teacherscourse for the student's request, so check to see if the student's request has a conflict with a current class, if not, a new class can be made
  result = false
  $teacherscourses[teachersname].each do |key, value|
      #if there is not a date conflict, then there is not a time conflict
      #first check for date conflict,  if none, make course, if there is a conflict, check for time conflict, if none make course, else push time and/or date conflict
    if value["startdate"] == startdate || value["enddate"] == enddate || enddate >= value["startdate"] && enddate < value["enddate"] || value["enddate"] >= startdate && value["enddate"] < enddate || startdate >= value["startdate"] && startdate < value["enddate"] || value["startdate"] >= startdate && value["startdate"] < enddate
      if  value["starttime"] == starttime || value["endtime"] == endtime || endtime >= value["starttime"] && enddate < value["endtime"] || value["endtime"] >= starttime && value["endtime"] < endtime || starttime >= value["starttime"] && starttime < value["endtime"] || value["starttime"] >= starttime && value["starttime"] < endtime
        addConflict(id, "Teacher has another course during that date / time")
        result = true
        break
      end
    end
  end
  return result
end

def setStudentsCourses(studentsname, teacher, trainingtype, startdate, enddate, starttime, endtime)
  if $studentscourses[studentsname] == nil 
    $studentscourses[studentsname] = {}
  end
  $studentscourses[studentsname]["course#{$studentscourses["counter"]}"] = {}
  course = $studentscourses[studentsname]["course#{$studentscourses["counter"]}"]
  course["teacher"] = teacher
  course["trainingtype"] = trainingtype
  course["startdate"] = startdate
  course["enddate"] = enddate
  course["starttime"] = starttime
  course["endtime"] = endtime
  $studentscourses["counter"] += 1
end


def addConflict(id, message)
  if $conflicts.length == 0 
    $conflicts.push(["", "Request ID: #{id}", "Reason for conflict: #{message}", ""]) 
  else
    $conflicts[0][2] = $conflicts[0][2] + ", Reason for conflict: #{message}"
  end
end

def teacherExist(teachersname, id)
  result = false
  $ia.select do |course|
    if teachersname == course[0]
      result = true
    end
  end
  if result == false
    addConflict(id, "No such teacher")
  end
  return result
end

def anyCoursesMatch(teachersname, trainingtype, id)
  result = false
  $matchingCourseTypes = $ia.select do |course|
    teachersname == course[0] && trainingtype == course[1]
  end
  if $matchingCourseTypes.length == 0
    addConflict(id, "This teacher does not offer that course type")
  end
end

def generalConflictCatcher(startdate, enddate, starttime, endtime, trainingtype, teachersname, id)
  $matchingCourseTypes.each do |x|
    # check start dates
    if startdate < x[3] || startdate > x[4]
      addConflict(id, "Can not start at this date")
    end
    #check end dates
    if enddate > x[4] || enddate < x[3]
      addConflict(id, "Can not end at this date")
    end
    # check start times
    if starttime < x[5] || starttime > x[6]
      addConflict(id, "Can not start at this time")
    end
    #check end times
    if endtime > x[6] || endtime < x[5]
      addConflict(id, "Can not end at this time")
    end
    #check for more than 1 group time block attempt
    if trainingtype == "Group Lesson" && (Time.parse(endtime) - Time.parse(starttime)) / 3600 > 1
      addConflict(id, "Cannot schedule a group lesson for more than 1 hour in length")
    end
    #private lessons with Jane must be in 30 minute increments
    if trainingtype == "Private Lesson" && teachersname == "jane doe" && ((Time.parse(endtime) - Time.parse(starttime)) / 60) % 30 != 0
      addConflict(id, "Private lessons with Jane must be in 30 minute increments")
    end
    #group lessons with Jane must be in 45 minute increments
    if trainingtype == "Group Lesson" && teachersname == "jane doe" && ((Time.parse(endtime) - Time.parse(starttime)) / 60) % 45 != 0
      addConflict(id, "Group lessons with Jane must be in 45 minute increments")
    end
  end
end

def isClassFull(courseType, courseStartTime, reqStartTime, courseEndTime, reqEndTime, courseStartDate, reqStartDate, courseEndDate, reqEndDate, courseMaxParticipants, id)
  if courseType == "Group Lesson" && courseStartTime == reqStartTime && courseEndTime == reqEndTime && courseStartDate == reqStartDate && courseEndDate == reqEndDate
    if courseMaxParticipants < 1
      addConflict(id, "Class is full")
    end
  end
end

def studentsOwnCoursesConflictCheck(studentsname, starttime, endtime, startdate, enddate, id)
  if $studentscourses[studentsname]
    $studentscourses[studentsname].each do | key, value |
      if value["startdate"] == startdate || value["enddate"] == enddate || enddate >= value["startdate"] && enddate < value["enddate"] || value["enddate"] >= startdate && value["enddate"] < enddate || startdate >= value["startdate"] && startdate < value["enddate"] || value["startdate"] >= startdate && value["startdate"] < enddate
        if  value["starttime"] == starttime || value["endtime"] == endtime || endtime >= value["starttime"] && enddate < value["endtime"] || value["endtime"] >= starttime && value["endtime"] < endtime || starttime >= value["starttime"] && starttime < value["endtime"] || value["starttime"] >= starttime && value["starttime"] < endtime
        addConflict(id, "Interferes with student's other scheduled course")
        end
      end
    end
  end
end

# end helper functions

# now we'll feed each row from $request through to see if a course can be made or if there are conflicts, the end for this is the very last end of the file
$request.each do |row|
  # reset conflicts
  $conflicts = [];
  # step 1 - check to see if teacher exist, if not, add to conflicts, and go to next api request
  teacherExist(row[7], row[0])
  #end step 1
  # step 2 - see if teacher offers course type at dates wanted and times wanted
  # grab the courses by teacher name that match students request
  # grab courses offered from that teacher that trainging types match
  anyCoursesMatch(row[7], row[2], row[0])
  # end step 2
  # step 3 look for general conflicts about this course offered, that would make it impossible to attempt to sign up for a course
  generalConflictCatcher(row[3], row[5], row[4], row[6], row[2], row[7], row[0])
  #if any of the above three function calls result in a conflict, then $conflicts will have a length, and the next iteration will take place
  #end step 3
  #if there are any conflict then we don't need to go any further, signing up for a course would be impossible, if there are any conflicts then this iteration will just end and print whatever conflicts there are. 
  if $conflicts.length == 0
    #for group lessons
    if row[2] == "Group Lesson"
      #does this teacher have any courses set yet?
      if $teacherscourses[row[7]]
        #if there are teachers courses with that name then they will be itereated through, and if the requested course doesn't match up with a current teacher's course, 
        #then $noMatch will reamin true, techerCourseConflictChecker is run to see if the requested course would conflict with a course the teacher currently has
        # the class is made.  I cannot set teachers course while iterating through teacherscourses, so instead
        #needToUpdate is set to to true, so once breaking out from the iteration, the teacherscourse can be set.
        $noMatch = true
        # makes sure that every course on teacherscourses has been checked for an exact match
        $teacherscourses[row[7]].each do | key, value |
            # check for full class first
          isClassFull(value["trainingtype"], value["starttime"], row[4], value["endtime"], row[6], value["startdate"], row[3], value["enddate"], row[5], value["maxparticipants"], row[0])
            #do any of this teachers group courses match up with the requested course from student, and is the max participation greater than 0?
          if value["trainingtype"] == "Group Lesson" && value["starttime"] == row[4] && value["endtime"] == row[6] && value["startdate"] == row[3] && value["enddate"] == row[5] && value["maxparticipants"] > 0
            $noMatch = false
            #does the student have any courses currentl
            if $studentscourses[row[1]]
              #are there any conflicts with student's schedule and this course's schedule?
              studentsOwnCoursesConflictCheck(row[1], row[4], row[6], row[3], row[5], row[0])
              if $conflicts.length == 0
                setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
                $teacherscourses[row[7]][key]["maxparticipants"] -= 1
              end
            #since student has no courses currently, there is no conflict, subtract one from maxparticipation and set course on student's courses
            else  
              setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
              $teacherscourses[row[7]][key]["maxparticipants"] -= 1
            end
          end
        end
          #teachercourses does not currently have a course that matches student's request.  Will making a new class conflict with any current teacher's courses
        if $noMatch
          if !teacherCoursesConflictChecker(row[4], row[6], row[3], row[5], row[7], row[0])
            setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
            setTeachersCourses(row[7],$matchingCourseTypes[0][2], row[2], row[3], row[5], row[4], row[6])
            next
          end
        end
        #if there are currently no teachers courses do this:
      else  
        studentsOwnCoursesConflictCheck(row[1], row[4], row[6], row[3], row[5], row[0])
        if $conflicts.length == 0
          setTeachersCourses(row[7], $matchingCourseTypes[0][2], row[2], row[3], row[5], row[4], row[6])
          setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
        end
      end
    end
    # the above end ends if group lesson
    if row[2] == "Private Lesson"
      #does this teacher have any courses set yet?
      if $teacherscourses[row[7]]
        if !teacherCoursesConflictChecker(row[4], row[6], row[3], row[5], row[7], row[0])
          studentsOwnCoursesConflictCheck(row[1], row[4], row[6], row[3], row[5], row[0])
          if $conflicts.length == 0
            setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
            setTeachersCourses(row[7],$matchingCourseTypes[0][2], row[2], row[3], row[5], row[4], row[6])
            next
          end
        end
        #if there are currently no teachers courses do this:
      else  
        studentsOwnCoursesConflictCheck(row[1], row[4], row[6], row[3], row[5], row[0])
        if $conflicts.length == 0
          setTeachersCourses(row[7], $matchingCourseTypes[0][2], row[2], row[3], row[5], row[4], row[6])
          setStudentsCourses(row[1], row[7], row[2], row[3], row[5], row[4], row[6])
        end
      end
    end
    # the above end is for if private lesson
  end
  # the above end ends the if conflicts.length == 0
  puts $conflicts
end


