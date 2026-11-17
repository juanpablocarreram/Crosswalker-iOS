package com.example.crosswalker

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import android.graphics.Bitmap
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

/** Runs the pinned Android app through its controls; never ticks or replaces the simulation. */
class CrossPlatformExecutionTest {
    @get:Rule val ui = createAndroidComposeRule<MainActivity>()
    private val session get() = ViewModelProvider(ui.activity)[Session::class.java]
    private fun tap(text: String) {
        val node = ui.onNodeWithText(text, substring = true)
        if (session.screen == "game") node.performTouchInput { click() } else node.performClick()
        ui.waitForIdle()
        ui.waitUntil(10000) { !session.transitioning }
    }
    private fun capture(name: String) {
        ui.waitForIdle()
        Thread.sleep(if (name == "home") 1200 else 350)
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val folder = File(ui.activity.getExternalFilesDir(null), "execution").apply { mkdirs() }
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    @Test fun tutorialAndTwelveLevels() {
        ui.runOnIdle { session.repo.resetProgress() }
        ui.waitUntil(10000) { !session.transitioning }
        capture("home")
        tap("JUGAR")
        capture("world-map")
        tap("Mi primer cruce")
        tap("PREPARAR EL PLAN")
        capture("tutorial-closed")
        tap("ABRIR PLAN")
        for (index in 0 until session.level.introLines.lastIndex) {
            if (index == 2) {
                capture("tutorial-map")
                tap("ABRIR PLAN")
            } else {
                val before = session.introIndex
                capture("tutorial-%02d".format(index))
                if (index == 1) {
                    tap("Ⅱ")
                    assertTrue(session.paused)
                    capture("tutorial-pause")
                    tap("CONTINUAR")
                    tap("CERRAR PLAN")
                    tap("ABRIR PLAN")
                    assertEquals(before, session.introIndex)
                }
                ui.onNodeWithContentDescription(session.level.introLines[index]).performTouchInput { click() }
                ui.waitForIdle()
                assertEquals(before + 1, session.introIndex)
            }
        }
        capture("tutorial-crossing")
        tap("Centro")
        capture("tutorial-look")
        tap("¿Para qué sirve?")
        capture("tutorial-tool-help")
        tap("ENTENDIDO")
        tap("MIRAR")
        capture("tutorial-launch")
        tap("PONER EL PLAN EN MARCHA")
        val first = session.simulation!!
        val y = first.people.first().y
        capture("level-01-running-start")
        ui.waitUntil(10000) { first.people.first().y != y }
        capture("level-01-running-moved")
        tap("Ⅱ")
        val pausedTime = first.time
        Thread.sleep(700)
        assertEquals(pausedTime, first.time)
        capture("simulation-pause")
        tap("CONTINUAR")
        ui.waitUntil(60000) { session.showResultDialog }
        assertEquals(com.example.crosswalker.game.Phase.WON, first.phase)
        capture("level-01-won")
        tap("VOLVER A INTENTAR")
        tap("ABRIR PLAN")
        tap("MIRAR")
        tap("Der.")
        capture("unsafe-plan")
        tap("PONER EL PLAN EN MARCHA")
        ui.waitUntil(30000) { session.showResultDialog }
        assertEquals(com.example.crosswalker.game.Phase.RETRY, session.simulation!!.phase)
        capture("collision-result")
        tap("MEJORAR MI PLAN")
        tap("ABRIR PLAN")
        tap("Centro")
        tap("MIRAR")
        tap("PONER EL PLAN EN MARCHA")
        ui.waitUntil(30000) { session.showResultDialog }
        assertEquals(com.example.crosswalker.game.Phase.WON, session.simulation!!.phase)
        capture("retry-won")
        val plans = JSONArray(PLANS)
        for (i in 0 until plans.length()) {
            val plan = plans.getJSONObject(i)
            val id = plan.getInt("level")
            tap("SIGUIENTE CAMINO")
            assertEquals(id, session.level.id)
            tap("ABRIR PLAN")
            val skills = plan.getJSONObject("skills")
            session.level.walkers.forEachIndexed { index, walker ->
                tap(walker.name)
                assertEquals(walker.id, session.selected)
                tap(listOf("Izq.", "Centro", "Der.")[plan.getJSONArray("crossings").getInt(index)])
                assertEquals(plan.getJSONArray("crossings").getInt(index), session.plan.people.getValue(walker.id).crossing)
                val chosen = skills.optJSONArray(walker.id) ?: JSONArray()
                for (j in 0 until chosen.length()) {
                    val tool = session.repo.tools.first { it.id == chosen.getString(j) }
                    ui.onNodeWithText(tool.label.uppercase()).performScrollTo().performTouchInput { click() }
                    ui.waitForIdle()
                    assertTrue(tool.id in session.plan.people.getValue(walker.id).skills)
                }
            }
            val street = plan.getJSONArray("street")
            if (street.length() > 0) {
                tap("LA CALLE")
                for (j in 0 until street.length()) {
                    val tool = session.repo.tools.first { it.id == street.getString(j) }
                    ui.onNodeWithText(tool.label.uppercase()).performScrollTo().performTouchInput { click() }
                    ui.waitForIdle()
                    assertTrue(tool.id in session.plan.street)
                }
            }
            capture("level-%02d-plan".format(id))
            tap("PONER EL PLAN EN MARCHA")
            val sim = session.simulation!!
            val initial = sim.people.map { it.y }
            ui.waitUntil(40000) { sim.people.map { it.y } != initial }
            capture("level-%02d-running".format(id))
            ui.waitUntil(90000) { sim.phase != com.example.crosswalker.game.Phase.RUNNING }
            assertEquals("Level $id: ${sim.reason}", com.example.crosswalker.game.Phase.WON, sim.phase)
            ui.waitUntil(10000) { session.showResultDialog || session.screen == "credits" }
            assertTrue(session.repo.stars(id) > 0)
            capture("level-%02d-won".format(id))
        }
    }
    companion object { const val PLANS = """[{"name": "guidance", "level": 2, "crossings": [1], "skills": {"tomas": ["look", "phone_away"]}, "street": []}, {"name": "guidance", "level": 3, "crossings": [1], "skills": {"mateo": ["look"]}, "street": ["crosswalk"]}, {"name": "guidance", "level": 4, "crossings": [1], "skills": {"leo": ["headphones_off", "look"]}, "street": []}, {"name": "guidance", "level": 5, "crossings": [1, 0], "skills": {"ana": ["escort", "look"], "tomas": ["look", "phone_away"]}, "street": []}, {"name": "guidance", "level": 6, "crossings": [1, 0], "skills": {"ana": ["look"], "mateo": ["look"]}, "street": ["crosswalk"]}, {"name": "guidance", "level": 7, "crossings": [1, 0], "skills": {"luz": ["look"], "ana": ["look"]}, "street": ["speed_zone"]}, {"name": "guidance", "level": 8, "crossings": [1, 0], "skills": {"luz": ["look"], "mateo": ["look"]}, "street": ["crosswalk"]}, {"name": "guidance", "level": 9, "crossings": [1], "skills": {}, "street": ["car_lights", "speed_zone"]}, {"name": "guidance", "level": 10, "crossings": [0, 2], "skills": {"tomas": ["phone_away"]}, "street": ["car_lights", "speed_zone"]}, {"name": "guidance", "level": 11, "crossings": [1, 0], "skills": {}, "street": ["car_lights", "speed_zone"]}, {"name": "guidance", "level": 12, "crossings": [1, 0, 2], "skills": {"tomas": ["phone_away"]}, "street": ["car_lights", "crosswalk", "speed_zone"]}]""" }
}
