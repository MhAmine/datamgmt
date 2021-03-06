library(arcticdatautils)
library(dataone)
library(EML)

context("Update EML physical (helper function)")

test_that("update_physical works", {
    cnTest <- dataone::CNode('STAGING')
    mnTest <- dataone::getMNode(cnTest,'urn:node:mnTestARCTIC')

    if (!arcticdatautils::is_token_set(mnTest)) {
        skip("No token set. Skipping test.")
    }

    #make dummy pkg/data
    pkg <- create_dummy_package2(mnTest,
                                 title = "update phys check")

    file.create("dummy_object.csv")

    new_data_pid <- arcticdatautils::update_object(mnTest,
                                                   pid = pkg$data[2],
                                                   path = "dummy_object.csv",
                                                   format_id = "text/csv")

    file.remove("dummy_object.csv")

    pkg_new <- arcticdatautils::publish_update(
        mnTest,
        resource_map_pid = pkg$resource_map,
        metadata_pid = pkg$metadata,
        data_pids = c(pkg$data[-2],
                      new_data_pid))

    eml_original <- EML::read_eml(rawToChar(dataone::getObject(mnTest,
                                                               pkg$metadata)))

    eml_new <- update_physical(eml_original,
                               mnTest,
                               data_pid = pkg$data[2],
                               new_data_pid = new_data_pid)

    url_original <- unlist(EML::eml_get(eml_original, "url"))
    url_new <- unlist(EML::eml_get(eml_new, "url"))

    #check pids in old package
    expect_equal(sum(stringr::str_detect(url_original,
                                         pkg$data[1])),
                 1)
    expect_equal(sum(stringr::str_detect(url_original,
                                         pkg$data[2])),
                 1)
    expect_equal(sum(stringr::str_detect(url_original,
                                         pkg$data[3])),
                 1)
    expect_equal(sum(stringr::str_detect(url_original,
                                         pkg$data[4])),
                 1)

    #check pids of new package
    expect_equal(sum(stringr::str_detect(url_new,
                                         new_data_pid)),
                 1)
    expect_equal(sum(stringr::str_detect(url_new,
                                         pkg$data[1])),
                 1)
    expect_equal(sum(stringr::str_detect(url_new,
                                         pkg$data[2])),
                 0)
    expect_equal(sum(stringr::str_detect(url_new,
                                         pkg$data[3])),
                 1)
    expect_equal(sum(stringr::str_detect(url_new,
                                         pkg$data[4])),
                 1)
})

context("Update object & resource map")

test_that("specified data object is changed; rest of package is intact", {
    cnTest <- dataone::CNode('STAGING')
    mnTest <- dataone::getMNode(cnTest,'urn:node:mnTestARCTIC')

    if (!arcticdatautils::is_token_set(mnTest)) {
        skip("No token set. Skipping test.")
    }

    #make dummy pkg/data
    pkg <- create_dummy_package2(mnTest,
                                 "check update_package_object")

    new_data_path <- "test_file.csv"
    file.create(new_data_path)

    data_pid <- pkg$data[2]

    pkg_new <- update_package_object(mnTest,
                                     data_pid = data_pid,
                                     new_data_path = new_data_path,
                                     resource_map_pid = pkg$resource_map,
                                     format_id = "text/csv")

    file.remove(new_data_path)

    #test: other objects are retained
    expect_equal(all(pkg$data[-2] %in% pkg_new$data), TRUE)

    #test: metadata changes
    expect_false(pkg$metadata == pkg_new$metadata)

    #test: new data pid is a version of old data pid
    versions <- arcticdatautils::get_all_versions(mnTest, data_pid)
    latest_version <- versions[length(versions)]

    new_data_pid <- pkg_new$data[!pkg_new$data %in% pkg$data]

    expect_equal(latest_version, new_data_pid)

    #test: eml is updated
    eml_original <- EML::read_eml(rawToChar(dataone::getObject(mnTest,
                                                               pkg$metadata)))

    eml_new <- EML::read_eml(rawToChar(dataone::getObject(mnTest,
                                                          pkg_new$metadata)))

    url_original <- unlist(EML::eml_get(eml_original, "url"))
    url_new <- unlist(EML::eml_get(eml_new, "url"))

    expect_true(url_original[2] != url_new[2])
    expect_equal(url_original[1], url_new[1])
    expect_equal(url_original[3], url_new[3])
    expect_equal(url_original[4], url_new[4])

    expect_true(stringr::str_detect(url_new[2], new_data_pid))
})

test_that("argument checks work", {
    cnTest <- dataone::CNode('STAGING')
    mnTest <- dataone::getMNode(cnTest,'urn:node:mnTestARCTIC')

    if (!arcticdatautils::is_token_set(mnTest)) {
        skip("No token set. Skipping test.")
    }

    file_path <- tempfile(fileext = ".csv")

    expect_error(update_package_object(LETTERS,
                                       data_pid = file_path,
                                       new_data_path = "something",
                                       rm_pid = "something"))

    expect_error(update_package_object(mnTest,
                                       data_pid = c(1, 2),
                                       new_data_path = "something",
                                       rm_pid = "something"))

    expect_error(update_package_object(mnTest,
                                       data_pid = "something",
                                       new_data_path = "something", #should throw error bc file doesn't exist
                                       rm_pid = "something"))

    expect_error(update_package_object(mnTest,
                                       data_pid = "something",
                                       new_data_path = TRUE,
                                       rm_pid = "something"))

    expect_error(update_package_object(mnTest,
                                       data_pid = file_path,
                                       new_data_path = "something",
                                       rm_pid = 1))
    file.remove(file_path)
})


test_that("EML updates", {
    cnTest <- dataone::CNode('STAGING')
    mnTest <- dataone::getMNode(cnTest,'urn:node:mnTestARCTIC')

    if (!arcticdatautils::is_token_set(mnTest)) {
        skip("No token set. Skipping test.")
    }

    #make dummy pkg/data
    pkg <- arcticdatautils::create_dummy_package(mnTest,
                                                 size = 4)

    #dummy data table:
    attributes1 <- data.frame(
        attributeName = c('col1', 'col2'),
        attributeDefinition = c('Numbers', 'Letters in the alphabet'),
        measurementScale = c('ratio', 'nominal'),
        domain = c('numericDomain', 'textDomain'),
        formatString = c(NA,NA),
        definition = c(NA,'ABCDEFG...'),
        unit = c('dimensionless', NA),
        numberType = c('integer', NA),
        missingValueCode = c(NA, NA),
        missingValueCodeExplanation = c(NA, NA),
        stringsAsFactors = FALSE)

    attributeList1 <- set_attributes(attributes1)
    phys <- pid_to_eml_physical(mnTest, pkg$data[1])

    dummy_data_table <- new('dataTable',
                            entityName = 'Dummy Data Table',
                            entityDescription = 'Dummy Description',
                            physical = phys,
                            attributeList = attributeList1)

    eml <- read_eml(rawToChar(getObject(mnTest, pkg$metadata)))
    eml@dataset@dataTable <- c(dummy_data_table)

    #create dummy otherEntities
    otherEnts <- pid_to_eml_other_entity(mnTest, pkg$data[2:3])
    eml@dataset@otherEntity <- new("ListOfotherEntity",
                                   otherEnts)

    eml_path <- tempfile(fileext = ".xml")
    write_eml(eml, eml_path)

    pkg <- publish_update(mn,
                          metadata_pid = pkg$metadata,
                          resource_map_pid = pkg$resource_map,
                          data_pids = pkg$data,
                          metadata_path = eml_path,
                          use_doi = use_doi,
                          public = public)
    #the dataset now has a dataTable, and two otherEntities

    dummy_data <- data.frame(col1 = 1:26, col2 = letters)
    new_data_path <- tempfile(fileext = ".csv")
    write.csv(dummy_data, new_data_path, row.names = FALSE)

    data_pid <- pkg$data[2]

    pkg_new <- update_package_object(mnTest,
                                     data_pid,
                                     new_data_path,
                                     pkg$resource_map,
                                     format_id = "text/csv")

    url_initial <- unlist(eml_get(eml, "url"))
    expect_equal(sum(stringr::str_count(url_initial, data_pid)),
                 1)

    eml_new <- read_eml(rawToChar(getObject(mnTest,
                                            pkg_new$metadata)))
    url_final <- unlist(eml_get(eml_new, "url"))
    expect_equal(sum(stringr::str_count(url_final, data_pid)),
                 0)

    pid_matches <- lapply(seq_along(pkg_new$data),
                          function(i) {stringr::str_count(url_final,
                                                          pkg_new$data[i])})

    #confirm that url's have a matching pid
    #if new pid corresponds to a dataset that had a dataTable/otherEntity
    #and has NOT been updated, expect_equal will throw an error
    expect_equal(sum(unlist(pid_matches)),
                 length(url_final))

})


